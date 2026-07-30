#!/usr/bin/env python3
# ===----------------------------------------------------------------------===##
#
# Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# ===----------------------------------------------------------------------===##
"""Differential check: llvm-mc vs nds32be-elf-as for every mfsr/mtsr sysreg.

Binutils is ground truth. Any byte mismatch, any name llvm-mc rejects, and any
round-trip (assemble -> llvm-objdump -> name) mismatch is a failure.

This is the acceptance gate for NDS32SysRegs.td: it is the reason a generated
table can be trusted at all, so run it after any change to the sysregs.

Configuration (env):
  TC        directory holding nds32be-elf-as / nds32be-elf-objdump
  LLVM_BIN  directory holding llvm-mc / llvm-objdump
Both default relative to this file's position in the LLVM tree.
"""
import os, re, subprocess, sys, tempfile

# .../llvm/utils/NDS32/verify-sysregs.py -> .../llvm
_LLVM = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TD = os.path.join(_LLVM, "lib", "Target", "NDS32", "NDS32SysRegs.td")
TC = os.environ.get(
    "TC", os.path.expanduser("~/projekty/nds32be-build/toolchain/bin"))
LB = os.environ.get(
    "LLVM_BIN", os.path.join(os.path.dirname(_LLVM), "build", "bin"))
AS, GOD = f"{TC}/nds32be-elf-as", f"{TC}/nds32be-elf-objdump"
for _p, _hint in ((AS, "TC"), (f"{LB}/llvm-mc", "LLVM_BIN")):
    if not os.path.exists(_p):
        sys.exit(f"not found: {_p}  (set {_hint})")
MC, LOD = f"{LB}/llvm-mc", f"{LB}/llvm-objdump"
TRIPLE = "nds32be-unknown-none-elf"

# Canonical names + aliases straight out of the generated table.
# Every spelling, plus the name each one is EXPECTED to decode back to. Aliases
# are tagged `// == $canonical` by the generator and must decode to that
# canonical name, not to themselves.
names, aliases, canon_of = [], [], {}
for line in open(TD):
    m = re.match(r'def SR_\w+ : NDS32SR<"\$(\w+)", \d+>;\s*(?://\s*==\s*\$(\w+))?',
                 line)
    if m:
        n, c = m.group(1), m.group(2)
        names.append(n)
        canon_of[n] = c or n
        if c:
            aliases.append(n)
print(f"sysreg spellings: {len(names)}   (of which aliases: {len(aliases)})")

def gnu_bytes(lines):
    with tempfile.TemporaryDirectory() as d:
        s, o = f"{d}/t.s", f"{d}/t.o"
        open(s, "w").write("\n".join(lines) + "\n")
        if subprocess.run([AS, "-march=v3", s, "-o", o],
                          capture_output=True).returncode:
            return None
        dis = subprocess.run([GOD, "-d", o], capture_output=True,
                             text=True).stdout
        return [int(m.group(1).replace(" ", ""), 16) for m in
                (re.match(r"\s*[0-9a-f]+:\s+((?:[0-9a-f]{2} ){4})", l)
                 for l in dis.splitlines()) if m]

def llvm_bytes(lines):
    with tempfile.TemporaryDirectory() as d:
        s = f"{d}/t.s"
        open(s, "w").write("\n".join(lines) + "\n")
        r = subprocess.run([MC, f"--triple={TRIPLE}", "-mcpu=v3",
                            "--show-encoding", s],
                           capture_output=True, text=True)
        if r.returncode:
            return None, r.stderr
        out = []
        for m in re.finditer(r"encoding:\s*\[([^\]]+)\]", r.stdout):
            bs = [int(x, 16) for x in re.findall(r"0x([0-9a-fA-F]{2})",
                                                 m.group(1))]
            out.append(int.from_bytes(bytes(bs), "big"))
        return out, r.stderr

fails = 0
for mn in ("mfsr $r0,", "mtsr $r0,"):
    verb = mn.split()[0]
    lines = [f"{mn}${n}" for n in names]
    g = gnu_bytes(lines)
    l, err = llvm_bytes(lines)
    if g is None:
        print(f"FAIL {verb}: binutils rejected the batch"); fails += 1; continue
    if l is None:
        print(f"FAIL {verb}: llvm-mc rejected the batch:\n{err[:600]}")
        fails += 1; continue
    if len(g) != len(names) or len(l) != len(names):
        print(f"FAIL {verb}: count gnu={len(g)} llvm={len(l)} want={len(names)}")
        fails += 1; continue
    bad = [(n, a, b) for n, a, b in zip(names, g, l) if a != b]
    if bad:
        fails += 1
        print(f"FAIL {verb}: {len(bad)} byte mismatches, first 8:")
        for n, a, b in bad[:8]:
            print(f"    ${n:14} gnu=0x{a:08x}  llvm=0x{b:08x}")
    else:
        print(f"PASS {verb}: {len(names)}/{len(names)} encodings byte-identical "
              "to binutils")

# Round-trip: llvm-objdump must decode back to the canonical name.
with tempfile.TemporaryDirectory() as d:
    s, o = f"{d}/t.s", f"{d}/t.o"
    open(s, "w").write("\n".join(f"mtsr $r0,${n}" for n in names) + "\n")
    subprocess.run([MC, f"--triple={TRIPLE}", "-mcpu=v3", "-filetype=obj",
                    s, "-o", o], capture_output=True)
    dis = subprocess.run([LOD, "-d", f"--triple={TRIPLE}", o],
                         capture_output=True, text=True).stdout
    got = re.findall(r"mtsr\s+\$r0,\s*\$(\w+)", dis)
    want = [canon_of[n] for n in names]
    if got != want:
        fails += 1
        diff = [(n, w, g) for n, w, g in zip(names, want, got) if w != g][:8]
        print(f"FAIL round-trip: decoded {len(got)}/{len(names)}; "
              f"(input, want, got) {diff}")
    else:
        print(f"PASS round-trip: all {len(names)} spellings decode back to "
              "their canonical name")

print("ALL SYSREG CHECKS GREEN" if not fails else f"{fails} CHECK(S) FAILED")
sys.exit(1 if fails else 0)
