#!/usr/bin/env bash
# ===----------------------------------------------------------------------===##
#
# Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# ===----------------------------------------------------------------------===##
# End-to-end test of REAL Rust `core` code on the nds32 sim.
#
# rustc has no nds32 target, so the project's nds32be-unknown-none.json is a
# MIPS impostor (arch=mips, big-endian, soft-float) — rustc emits MIPS-flavored
# LLVM IR that OUR llc retargets to nds32. This builds a small no_std crate whose
# C-ABI functions exercise core (count_ones/leading_zeros/swap_bytes/rotate_left,
# checked_add via Option, cmp::max, gcd, slice-iterator sum, isqrt), compiles the
# emitted IR with our llc, links it with an Andes-gcc main + newlib, and runs it
# on the sim. Proves the full pipeline: rustc -> our backend -> object -> run.
#
# Prereqs: rust nightly + rust-src (-Zbuild-std), the sim (scripts/build-nds32-sim.sh).
set -euo pipefail
CARGO="${CARGO:-$HOME/.cargo/bin/cargo}"
HERE="$(cd "$(dirname "$0")" && pwd)"
CRATE="$HERE/exec-test/rust"
TARGET_JSON="$HERE/../nds32be-unknown-none.json"

LLC=${LLC:-$HERE/../llvm22/build/bin/llc}
TC=${TC:-/home/dministrator/nds32be-build/toolchain/bin}
RUN=${RUN:-/home/dministrator/nds32be-build/nds32-gdb-sim/build-sim/sim/nds32/run}

cp "$TARGET_JSON" "$CRATE/nds32be-unknown-none.json"
cd "$CRATE"
RUSTFLAGS="--emit=llvm-ir -C panic=abort" "$CARGO" +nightly build \
  -Z build-std=core -Z json-target-spec \
  --target nds32be-unknown-none.json --release >/dev/null 2>&1

# Compile every emitted IR (rscore + core + compiler_builtins) with our llc.
# -function-sections + --gc-sections drops unused core code (e.g. paths that
# reference __atomic_load_N, absent on this single-hart target).
D=target/nds32be-unknown-none/release/deps
objs=""
for c in rscore core compiler_builtins; do
  ll=$(find "$D" -name "$c-*.ll" | head -1)
  [ -n "$ll" ] || { echo "missing IR: $c"; exit 1; }
  "$LLC" -mtriple=nds32be-unknown-none-elf -function-sections -filetype=obj "$ll" -o "$c.o"
  objs="$objs $c.o"
done
"$TC/nds32be-elf-gcc" -O2 -c main_rs.c -o main_rs.o
"$TC/nds32be-elf-gcc" -O2 main_rs.o $objs -o test_rs.elf \
  -Wl,--gc-sections -Wl,--allow-multiple-definition 2>/dev/null

set +e; "$RUN" test_rs.elf; code=$?; set -e
if [ "$code" -eq 0 ]; then echo "RUST CORE EXEC TEST PASS"; exit 0; fi
echo "RUST CORE EXEC TEST FAIL (exit $code)"; exit 1
