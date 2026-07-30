#!/usr/bin/env python3
# ===----------------------------------------------------------------------===##
#
# Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# ===----------------------------------------------------------------------===##
"""Normalize + diff two objdump -d listings (Andes ground truth vs LLVM).

Aligns instructions by address and classifies divergences. See diff-disasm.sh
for the contract. Output is a human summary plus a coverage worklist.
"""
import re
import sys
from collections import Counter

# ABI register aliases -> canonical $rN (NDS32 standard ABI).
ALIAS = {
    "$sp": "$r31", "$fp": "$r28", "$gp": "$r29", "$lp": "$r30",
    "$ta": "$r15", "$pc": "$pc",
}
# Mnemonic aliases that are legitimate print-side choices, not decode bugs.
# Canonicalize both sides so they don't show up as false mnemonic mismatches.
MNEMONIC_ALIAS = {
    "mov": "ori",   # llvm prints `ori rd,rs,0` as `mov`
}
# Branch/jump mnemonics whose single immediate operand is a PC-relative target.
# Andes prints the absolute address; llvm prints a signed displacement.
BRANCH_MNEMONICS = {
    "b", "bal", "j", "j8", "jal", "beqz", "bnez", "bgez", "bltz", "bgtz",
    "blez", "beq", "bne", "beqz38", "bnez38", "beqzs8", "bnezs8", "bgezal",
    "bltzal", "ifcall", "ifcall9", "beqc", "bnec", "beqs38", "bnes38",
}

LINE_RE = re.compile(r"^\s*([0-9a-fA-F]+):\s+((?:[0-9a-fA-F]{2} )+)\s*(.*)$")


def parse(path):
    """Return {addr: (mnemonic, operand_text)} from an objdump -d listing."""
    out = {}
    for line in open(path, errors="replace"):
        m = LINE_RE.match(line)
        if not m:
            continue
        addr = int(m.group(1), 16)
        insn = m.group(3).strip()
        if not insn:
            out[addr] = ("<none>", "")
            continue
        # strip objdump's trailing  <symbol+0x..> target annotation
        insn = re.sub(r"\s*<[^>]+>\s*$", "", insn).strip()
        # strip Andes' trailing "! {reg-list}" comment (derived from the fields)
        insn = re.sub(r"\s*!.*$", "", insn).strip()
        parts = re.split(r"[\t ]+", insn, maxsplit=1)
        mnem = parts[0]
        ops = parts[1] if len(parts) > 1 else ""
        out[addr] = (mnem, ops)
    return out


def canon_mnem(m):
    return MNEMONIC_ALIAS.get(m, m)


def norm_imm(tok):
    """Canonicalize an immediate token to a signed decimal string."""
    t = tok.lstrip("#")
    neg = t.startswith("-")
    t = t.lstrip("-+")
    try:
        v = int(t, 16) if t.lower().startswith("0x") else int(t, 10)
    except ValueError:
        return tok
    return str(-v if neg else v)


def norm_ops(ops):
    """Register-alias + immediate normalization, shift-by-0 elision."""
    s = ops
    for a, r in ALIAS.items():
        s = re.sub(re.escape(a) + r"\b", r, s)
    # drop `<< #0` / `<< 0` no-op shift display on reg-offset addressing
    s = re.sub(r"\s*<<\s*#?0\b", "", s)
    # collapse whitespace, normalize each immediate-looking token
    toks = re.split(r"([,\[\]()+]|\s+)", s)
    out = []
    for tk in toks:
        if re.fullmatch(r"#?-?(0x[0-9a-fA-F]+|\d+)", tk):
            out.append(norm_imm(tk))
        else:
            out.append(tk)
    return re.sub(r"\s+", " ", "".join(out)).strip()


def last_imm(ops):
    """Last immediate-looking token in ops (the branch target), or None."""
    s = re.sub(r"\$\w+", "", ops)
    toks = re.findall(r"-?(?:0x[0-9a-fA-F]+|[0-9a-fA-F]+)", s)
    return toks[-1] if toks else None


def llvm_branch_abs(addr, lo):
    """LLVM prints a signed displacement; fold with addr -> absolute target."""
    t = last_imm(lo)
    if t is None:
        return None
    v = int(t, 16) if "x" in t.lower() else int(t, 10)
    return addr + v


def andes_branch_abs(ao):
    """Andes prints the absolute target as bare hex."""
    t = last_imm(ao)
    return int(t, 16) if t is not None else None


IMM_RE = re.compile(r"#?-?(?:0x[0-9a-fA-F]+|\d+)")


def imms_of(ops):
    """Normalized signed-decimal immediate values in an operand string."""
    # exclude register tokens like $r12 (the digits there are reg numbers)
    s = re.sub(r"\$\w+", "", ops)
    s = s.replace("#", "")
    # join a sign that the printer separated from its number: "- 4" -> "-4",
    # "+ -4" -> "+-4" (so the value, not just its magnitude, is captured)
    s = re.sub(r"-\s+(?=\d|0x)", "-", s)
    return [norm_imm(t) for t in IMM_RE.findall(s)]


def main():
    andes = parse(sys.argv[1])
    llvm = parse(sys.argv[2])

    addrs = sorted(set(andes) | set(llvm))
    agree = mnem_mismatch = imm_mismatch = reg_mismatch = 0
    only_andes = only_llvm = gap = 0
    worklist = Counter()
    imm_examples, mnem_examples = [], []

    for a in addrs:
        ga, gl = andes.get(a), llvm.get(a)
        if ga and not gl:
            only_andes += 1
            continue
        if gl and not ga:
            only_llvm += 1
            continue
        am, ao = ga
        lm, lo = gl
        # Skip slots neither tool can decode (data/literal pools): pure noise.
        if "unknown" in am.lower():
            continue
        # LLVM coverage gap: unknown/byte/blank where Andes decoded a real insn
        if (not lm) or lm in ("<unknown>", ".byte", ".word", "<none>") \
                or "unknown" in lm.lower():
            gap += 1
            worklist[am] += 1
            if len(mnem_examples) < 30:
                mnem_examples.append((a, "GAP", f"{am} {ao}", f"{lm} {lo}"))
            continue
        if canon_mnem(am) != canon_mnem(lm):
            mnem_mismatch += 1
            if len(mnem_examples) < 30:
                mnem_examples.append((a, "MNEM", f"{am} {ao}", f"{lm} {lo}"))
            continue
        # Same mnemonic. Compare immediates (high signal: sign/scale bugs),
        # reconciling PC-relative branch targets (Andes abs vs LLVM rel disp).
        ai, li = imms_of(ao), imms_of(lo)
        if canon_mnem(am) in BRANCH_MNEMONICS:
            la, aa = llvm_branch_abs(a, lo), andes_branch_abs(ao)
            if la is not None and aa is not None:
                # The target is the trailing operand; compare any leading
                # immediates (e.g. beqc's compare value) directly, and reconcile
                # the PC-relative target (Andes absolute vs LLVM displacement).
                a_lead = imms_of(re.sub(r"[^,]*$", "", ao))
                l_lead = imms_of(re.sub(r"[^,]*$", "", lo))
                ai = a_lead + [str(aa)]
                li = l_lead + [str(la)]
        # Non-zero immediates must match exactly (real sign/scale bugs);
        # a difference of only elided zeros (mov==ori rd,rs,0; <<#0) is noise.
        anz = sorted(x for x in ai if norm_imm(x) != "0")
        lnz = sorted(x for x in li if norm_imm(x) != "0")
        if anz != lnz:
            imm_mismatch += 1
            if len(imm_examples) < 30:
                imm_examples.append((a, "IMM", f"{am} {ao}", f"{lm} {lo}"))
            continue
        # immediates agree; flag residual register/format differences quietly
        if norm_ops(ao).replace("(", "").replace(")", "") != \
                norm_ops(lo).replace("(", "").replace(")", ""):
            reg_mismatch += 1
            continue
        agree += 1

    total = len(addrs)
    print(f"=== diff-disasm: {total} instruction slots ===")
    print(f"  agree                  : {agree}")
    print(f"  IMMEDIATE mismatch     : {imm_mismatch}   <- decoder sign/scale bugs")
    print(f"  MNEMONIC mismatch      : {mnem_mismatch}")
    print(f"  LLVM coverage gap      : {gap}")
    print(f"  reg/format only (noise): {reg_mismatch}")
    print(f"  only in Andes / LLVM   : {only_andes} / {only_llvm}")
    if worklist:
        print("\n=== LLVM cannot-decode worklist (by frequency) ===")
        for mnem, n in worklist.most_common():
            print(f"  {n:5d}  {mnem}")
    if imm_examples:
        print("\n=== IMMEDIATE mismatches (addr / andes | llvm) ===")
        for a, kind, ax, lx in imm_examples:
            print(f"  {a:#08x}  {ax.strip():30s} | {lx.strip()}")
    if mnem_examples:
        print("\n=== MNEMONIC mismatches / gaps (addr / kind / andes | llvm) ===")
        for a, kind, ax, lx in mnem_examples:
            print(f"  {a:#08x} {kind:4s}  {ax.strip():26s} | {lx.strip()}")
    sys.exit(1 if (mnem_mismatch or gap or imm_mismatch) else 0)


if __name__ == "__main__":
    main()
