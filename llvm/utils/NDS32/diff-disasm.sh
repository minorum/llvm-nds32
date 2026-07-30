#!/usr/bin/env bash
# diff-disasm.sh — differential disassembly: LLVM vs Andes binutils ground truth.
#
# Runs both disassemblers over the same object/ELF .text and reports, per
# instruction (aligned by address):
#   * LLVM coverage gaps  — LLVM emits <unknown>/.byte/error where Andes decodes
#   * mnemonic mismatches  — different opcode decoded for the same bytes
#   * operand mismatches   — same mnemonic, different operands (branch targets
#                            are reconciled: LLVM's relative disp is folded with
#                            the instruction address and compared to Andes' abs)
#
# This is the trust gate for using the LLVM disassembler as an RE oracle, and it
# emits a frequency-ranked worklist of instructions LLVM cannot yet decode.
#
# Usage:  scripts/diff-disasm.sh <object-or-elf> [triple]
#   triple defaults to nds32be; pass nds32le for little-endian inputs.
# Env:    TC  = Andes toolchain bin dir (default below)
#         OD  = llvm-objdump path (default below)
set -euo pipefail

OBJ=${1:?usage: diff-disasm.sh <object-or-elf> [triple]}
TRIPLE=${2:-nds32be}
TC=${TC:-/home/dministrator/nds32be-build/toolchain/bin}
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OD=${OD:-$ROOT/llvm22/build/bin/llvm-objdump}
ANDES_OD="$TC/${TRIPLE%%-*}"-elf-objdump
# nds32le/nds32be both map to the nds32be-elf binutils objdump (it reads the
# ELF's endianness flag itself); only the LLVM side needs the triple.
[ -x "$ANDES_OD" ] || ANDES_OD="$TC/nds32be-elf-objdump"

tmpd=$(mktemp -d)
trap 'rm -rf "$tmpd"' EXIT

"$ANDES_OD" -d "$OBJ" 2>/dev/null > "$tmpd/andes.txt"
"$OD" -d --triple="$TRIPLE" "$OBJ" 2>/dev/null > "$tmpd/llvm.txt"

python3 "$ROOT/scripts/diff-disasm.py" "$tmpd/andes.txt" "$tmpd/llvm.txt"
