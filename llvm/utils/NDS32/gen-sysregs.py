#!/usr/bin/env python3
"""Generate the NDS32 system-register TableGen table from binutils ground truth.

Reads the `keyword_sr` table out of binutils' opcodes/nds32-asm.c for the NAME
list, then determines each name's SRIDX *empirically* by assembling
`mtsr $r0,$NAME` with nds32be-elf-as and extracting bits[19:5] of the encoding.
Never trusts a hand-derived macro.

Emits: registers grouped by unique SRIDX (canonical name + AltNames aliases).

Provenance note: the NAME LIST is read out of binutils' GPL-licensed source. The
names and their SRIDX values are hardware facts about the NDS32 ISA, and the
values here are obtained by running the assembler rather than by copying code --
but if you need to be scrupulous about the licence boundary, re-derive the name
list from the Andes ISA manual and keep binutils purely as the encoding oracle.
Nothing else in this fork depends on binutils source.

Configuration (env):
  NDS32_BINUTILS_SRC  path to binutils' opcodes/nds32-asm.c   (name list)
  TC                  directory holding nds32be-elf-as/objdump (encodings)
"""
import os, re, subprocess, sys, tempfile, collections

BU = os.environ.get(
    "NDS32_BINUTILS_SRC",
    os.path.expanduser("~/projekty/nds32be-build/binutils-2.45/opcodes/nds32-asm.c"))
TC = os.environ.get(
    "TC", os.path.expanduser("~/projekty/nds32be-build/toolchain/bin"))
AS, OD = f"{TC}/nds32be-elf-as", f"{TC}/nds32be-elf-objdump"

if not os.path.exists(BU):
    sys.exit(f"binutils source not found: {BU}  (set NDS32_BINUTILS_SRC)")
if not os.path.exists(AS):
    sys.exit(f"nds32be-elf-as not found: {AS}  (set TC)")

src = open(BU).read()
m = re.search(r"keyword_sr\s*\[\]\s*=\s*\{(.*?)\n\};", src, re.S)
if not m:
    sys.exit("keyword_sr table not found in binutils source")
names = re.findall(r'\{\s*"([A-Za-z0-9_]+)"\s*,', m.group(1))
# preserve order, drop dups
seen, ordered = set(), []
for n in names:
    if n not in seen:
        seen.add(n); ordered.append(n)
print(f"; keyword_sr names: {len(ordered)}", file=sys.stderr)

def encode(batch):
    """Assemble `mtsr $r0,$NAME` for each name; return {name: word} for accepted."""
    with tempfile.TemporaryDirectory() as d:
        s, o = f"{d}/t.s", f"{d}/t.o"
        with open(s, "w") as f:
            for n in batch:
                f.write(f"mtsr $r0,${n}\n")
        r = subprocess.run([AS, "-march=v3", s, "-o", o],
                           capture_output=True, text=True)
        if r.returncode != 0:
            return None
        dis = subprocess.run([OD, "-d", o], capture_output=True, text=True).stdout
        words = []
        for line in dis.splitlines():
            mm = re.match(r"\s*[0-9a-f]+:\s+((?:[0-9a-f]{2} ){4})", line)
            if mm:
                words.append(int(mm.group(1).replace(" ", ""), 16))
        if len(words) != len(batch):
            return None
        return dict(zip(batch, words))

got = encode(ordered)
if got is None:                       # some name rejected -> fall back per-name
    got = {}
    for n in ordered:
        r = encode([n])
        if r:
            got.update(r)
        else:
            print(f"; REJECTED by as: {n}", file=sys.stderr)

# SRIDX = bits[19:5]; sanity-check the fixed fields while we are here.
by_sridx = collections.OrderedDict()
for n, w in got.items():
    if (w >> 25) != 0x32 or (w & 0x1f) != 3 or ((w >> 20) & 0x1f) != 0:
        print(f"; UNEXPECTED encoding for {n}: 0x{w:08x}", file=sys.stderr)
        continue
    sridx = (w >> 5) & 0x7fff
    by_sridx.setdefault(sridx, []).append(n)

print(f"; accepted {len(got)} names -> {len(by_sridx)} unique SRIDX", file=sys.stderr)

out = []
# Standard LLVM file header (first line padded to 80 columns). Emitted here, not
# added by hand to the output, so that regenerating never drops it.
_head, _tail = "//===-- NDS32SysRegs.td - NDS32 system registers ", "-*- tablegen -*-===//"
out.append(_head + "-" * (80 - len(_head) - len(_tail)) + _tail)
out.append("//")
out.append("// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.")
out.append("// See https://llvm.org/LICENSE.txt for license information.")
out.append("// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception")
out.append("//")
out.append("//===----------------------------------------------------------------------===//")
out.append("")
out.append("// GENERATED FILE -- do not hand-edit. Regenerate with")
out.append("// scripts/gen-sysregs.py and verify with scripts/verify-sysregs.py.")
out.append("//")
out.append("// The name list comes from binutils' `keyword_sr`; each SRIDX is read back")
out.append("// out of real `nds32be-elf-as` output rather than reimplementing binutils'")
out.append("// SRIDX(major,minor,ext) macro. See mt6785-connsys-firmware")
out.append("// docs/07-environment-setup.md for the provenance and the acceptance gate.")
out.append("")
out.append("class NDS32SR<string n, bits<15> idx> : Register<n> {")
out.append('  let Namespace = "NDS32";')
out.append("  let HWEncoding{14-0} = idx;")
out.append("}")
out.append("")
out.append("// Canonical spellings. Listed FIRST in the SR class below because")
out.append("// NDS32Disassembler's DecodeSRRegisterClass returns the first member")
out.append("// matching an SRIDX -- so these, not the aliases, are what a decoded")
out.append("// mfsr/mtsr prints.")
canon_defs, alias_defs = [], []
for sridx, ns in by_sridx.items():
    canon, aliases = ns[0], ns[1:]
    dn = "SR_" + canon.upper()
    canon_defs.append(dn)
    out.append(f'def {dn} : NDS32SR<"${canon}", {sridx}>;')
    for a in aliases:
        alias_defs.append(("SR_" + a.upper(), a, sridx, canon))
out.append("")
out.append("// Alias spellings binutils also accepts (the numeric $crN/$irN/$drN")
out.append("// forms). Separate defs sharing the canonical register's SRIDX: the")
out.append("// asm parser resolves a name via the generated MatchRegisterName, so")
out.append("// an alias must be a register in its own right to be accepted.")
for dn, a, sridx, canon in alias_defs:
    out.append(f'def {dn} : NDS32SR<"${a}", {sridx}>;   // == ${canon}')
out.append("")
out.append("// Not allocatable: these are named operands of mfsr/mtsr only.")
defnames = canon_defs + [d for d, _, _, _ in alias_defs]
out.append('def SR : RegisterClass<"NDS32", [i32], 32, (add')
for i in range(0, len(defnames), 6):
    out.append("  " + ", ".join(defnames[i:i + 6]) + ("," if i + 6 < len(defnames) else ""))
out.append(")> {")
out.append("  let isAllocatable = 0;")
out.append("}")
print("\n".join(out))
