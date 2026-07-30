#!/usr/bin/env python3
# ===----------------------------------------------------------------------===##
#
# Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# ===----------------------------------------------------------------------===##
"""Generate NDS32SysRegs.td by probing the GNU nds32be-elf toolchain.

The table is derived ENTIRELY FROM TOOL OUTPUT -- no GPL source is read, and no
encoding macro is reimplemented:

  1. Canonical names: synthesise `mfsr $r0, <SRIDX>` for every architecturally
     distinct SRIDX and let `nds32be-elf-objdump` name it. Whatever the
     disassembler prints IS the canonical spelling, by definition.
  2. Alias names: for each numeric register family the ISA defines ($crN, $irN,
     $mrN, $drN, ...), ask `nds32be-elf-as` which spellings it accepts and read
     the SRIDX back out of the encoding it produced.

Only bytes in and bytes out; the assembler's *output* is not covered by the
assembler's licence, so the generated table carries no GPL obligation. (An
earlier version parsed binutils' `keyword_sr` C source for the name list, which
raised an unnecessary licence question. It no longer does, and the canonical set
it produces is identical: 136 registers.)

SRIDX occupies bits[19:5] of the instruction and is itself laid out as
major<<12 | minor<<8 | ext<<5, so its low 5 bits are don't-care -- enumerate in
steps of 32 or every register is reported as $cpu_ver.

Configuration (env):
  TC   directory holding nds32be-elf-as / nds32be-elf-objdump

Usage:  TC=/path/to/bin gen-sysregs.py > ../../lib/Target/NDS32/NDS32SysRegs.td
"""
import os, re, struct, subprocess, sys, tempfile

TC = os.environ.get(
    "TC", os.path.expanduser("~/projekty/nds32be-build/toolchain/bin"))
AS, OD = f"{TC}/nds32be-elf-as", f"{TC}/nds32be-elf-objdump"
for _p in (AS, OD):
    if not os.path.exists(_p):
        sys.exit(f"not found: {_p}  (set TC to the nds32be-elf toolchain bin dir)")

MFSR, MTSR = 2, 3          # sub-opcode, bits[4:0]
OPC = 0x32                 # bits[31:25]


def word(sridx, sub):
    return (OPC << 25) | (sridx << 5) | sub


# --- 1. canonical names, straight out of the disassembler --------------------
SRIDXS = list(range(0, 0x8000, 32))
with tempfile.TemporaryDirectory() as d:
    raw = os.path.join(d, "probe.bin")
    with open(raw, "wb") as f:
        f.write(b"".join(struct.pack(">I", word(s, MFSR)) for s in SRIDXS))
    dis = subprocess.run([OD, "-b", "binary", "-m", "nds32", "-EB", "-D", raw],
                         capture_output=True, text=True).stdout

canon = {}
for line in dis.splitlines():
    m = re.match(r"\s*([0-9a-f]+):\s+(?:[0-9a-f]{2} ){4}\s*(.*)", line)
    if not m:
        continue
    sridx = SRIDXS[int(m.group(1), 16) // 4]
    name = re.match(r"mfsr\s+\$r0,\s*\$(\w+)$", m.group(2).strip())
    if name:                      # unassigned SRIDX prints a bare number
        canon[sridx] = name.group(1)
if not canon:
    sys.exit("no system registers decoded -- is this really an nds32 objdump?")
print(f"; canonical registers discovered: {len(canon)}", file=sys.stderr)


# --- 2. alias spellings, straight out of the assembler -----------------------
# The numeric families the ISA defines. Membership is confirmed by the
# assembler; anything it rejects is simply dropped.
FAMILIES = ["cr", "ir", "mr", "dr", "pfr", "hspr", "dmar", "racr", "idr",
            "secur", "dimbr", "tecr"]
cands = [f"{p}{n}" for p in FAMILIES for n in range(64)]

with tempfile.TemporaryDirectory() as d:
    src, obj = os.path.join(d, "a.s"), os.path.join(d, "a.o")
    accepted = []
    # One name per assembler run would be 768 processes; instead bisect: try the
    # whole batch, and on failure fall back to per-name for that batch only.
    def try_batch(names):
        with open(src, "w") as f:
            f.write("".join(f"mtsr $r0,${n}\n" for n in names))
        r = subprocess.run([AS, "-march=v3", src, "-o", obj],
                           capture_output=True, text=True)
        if r.returncode:
            return None
        out = subprocess.run([OD, "-d", obj], capture_output=True,
                             text=True).stdout
        return [int(m.group(1).replace(" ", ""), 16) for m in
                (re.match(r"\s*[0-9a-f]+:\s+((?:[0-9a-f]{2} ){4})", l)
                 for l in out.splitlines()) if m]

    for p in FAMILIES:
        batch = [f"{p}{n}" for n in range(64)]
        words = try_batch(batch)
        if words is None:
            for n in batch:
                w = try_batch([n])
                if w:
                    accepted.append((n, w[0]))
        else:
            accepted += list(zip(batch, words))

alias = {}
for name, w in accepted:
    if (w >> 25) != OPC or (w & 0x1f) != MTSR or ((w >> 20) & 0x1f) != 0:
        print(f"; unexpected encoding for ${name}: 0x{w:08x}", file=sys.stderr)
        continue
    sridx = (w >> 5) & 0x7fff
    if sridx not in canon:
        print(f"; alias ${name} -> unknown SRIDX 0x{sridx:04x}", file=sys.stderr)
        continue
    if name != canon[sridx]:
        alias.setdefault(sridx, []).append(name)
print(f"; alias spellings discovered: {sum(len(v) for v in alias.values())}",
      file=sys.stderr)


# --- 3. emit ------------------------------------------------------------------
out = []
_h, _t = "//===-- NDS32SysRegs.td - NDS32 system registers ", "-*- tablegen -*-===//"
out += [_h + "-" * (80 - len(_h) - len(_t)) + _t,
        "//",
        "// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.",
        "// See https://llvm.org/LICENSE.txt for license information.",
        "// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception",
        "//",
        "//===----------------------------------------------------------------------===//",
        "",
        "// GENERATED FILE -- do not hand-edit. Regenerate with",
        "// llvm/utils/NDS32/gen-sysregs.py, verify with verify-sysregs.py.",
        "//",
        "// Derived entirely by probing the GNU nds32be-elf toolchain: canonical",
        "// names are whatever nds32be-elf-objdump prints for each architecturally",
        "// distinct SRIDX, and aliases are the numeric spellings nds32be-elf-as",
        "// accepts. Tool output only -- no GPL source is read and no encoding",
        "// macro is reimplemented.",
        "",
        "class NDS32SR<string n, bits<15> idx> : Register<n> {",
        '  let Namespace = "NDS32";',
        "  let HWEncoding{14-0} = idx;",
        "}",
        "",
        "// Canonical spellings. Listed FIRST in the SR class below because",
        "// NDS32Disassembler's DecodeSRRegisterClass returns the first member",
        "// matching an SRIDX -- so these, not the aliases, are what a decoded",
        "// mfsr/mtsr prints.",
        ]
canon_defs, alias_defs = [], []
for sridx in sorted(canon):
    n = canon[sridx]
    dn = "SR_" + n.upper()
    canon_defs.append(dn)
    out.append(f'def {dn} : NDS32SR<"${n}", {sridx}>;')
    for a in alias.get(sridx, []):
        alias_defs.append(("SR_" + a.upper(), a, sridx, n))

out += ["",
        "// Alias spellings the GNU assembler also accepts (the numeric $crN/$irN/",
        "// $drN forms). Separate defs sharing the canonical register's SRIDX: the",
        "// asm parser resolves a name via the generated MatchRegisterName, so an",
        "// alias must be a register in its own right to be accepted.",
        ]
for dn, a, sridx, c in alias_defs:
    out.append(f'def {dn} : NDS32SR<"${a}", {sridx}>;   // == ${c}')

out += ["", "// Not allocatable: these are named operands of mfsr/mtsr only.",
        'def SR : RegisterClass<"NDS32", [i32], 32, (add']
names = canon_defs + [d for d, _, _, _ in alias_defs]
for i in range(0, len(names), 6):
    out.append("  " + ", ".join(names[i:i + 6]) +
               ("," if i + 6 < len(names) else ""))
out += [")> {", "  let isAllocatable = 0;", "}"]
print("\n".join(out))
