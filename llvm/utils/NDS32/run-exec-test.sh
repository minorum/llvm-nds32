#!/usr/bin/env bash
# ===----------------------------------------------------------------------===##
#
# Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# ===----------------------------------------------------------------------===##
# End-to-end EXECUTION test: compile functions with OUR llc backend, call them
# from an Andes-gcc `main`, link with newlib, and run on the nds32 sim. This is
# the only check that verifies the backend's output actually RUNS correctly
# (and that our calling convention matches the real Andes ABI, since main and
# our functions are compiled by different toolchains and linked together).
#
# Covers (ours.ll / main.c): arithmetic, the i64 even-pair ABI, division/rem,
# i64 mul+shifts, narrow memory with sign/zero extension, global arrays
# (reg-offset addressing), jump-table switch, recursion, stack arguments,
# select, bswap/clz, immediate materialization, soft-float f32/f64, varargs,
# sret, small/large structs by value (incl. one straddling regs+stack), small
# struct return, pointer-in-data deref (data reloc / GOT), indirect calls via
# function pointer, and vararg doubles (8-byte even-pair save area). Runs in
# BOTH static and PIC modes (main.c returns 0 on ALL PASS).
#
# It has already caught four real silent miscompiles the lit suite missed:
#   - global loads emitting `sethi lo12`            (reg-offset folding)
#   - global data serialized little-endian          (MCAsmInfo endianness)
#   - PIC jump table relocated as R_NDS32_25_PCREL   (JT placed in .rodata)
#   - object emission crash on 2-byte .text padding  (writeNopData / nop16)
#
# Prereqs: build the sim once with scripts/build-nds32-sim.sh.
set -euo pipefail
cd "$(dirname "$0")/exec-test"

LLC=${LLC:-/home/dministrator/nds32-llvm/llvm22/build/bin/llc}
TC=${TC:-/home/dministrator/nds32be-build/toolchain/bin}
RUN=${RUN:-/home/dministrator/nds32be-build/nds32-gdb-sim/build-sim/sim/nds32/run}
TRIPLE=nds32be-unknown-none-elf

run_mode() { # $1 = label, $2... = extra llc/gcc flags split below
  local label=$1 llcflags=$2 gccflags=$3
  "$LLC" -mtriple=$TRIPLE $llcflags -filetype=obj ours.ll -o ours.o
  "$TC/nds32be-elf-gcc" -O2 $gccflags -c main.c -o main.o
  "$TC/nds32be-elf-gcc" -O2 $gccflags main.o ours.o -o test.elf 2>/dev/null
  set +e; "$RUN" test.elf; local code=$?; set -e
  if [ "$code" -eq 0 ]; then echo "[$label] EXEC TEST PASS"; return 0; fi
  echo "[$label] EXEC TEST FAIL (exit $code = failing-check count)"; return 1
}

rc=0
run_mode static ""                    ""      || rc=1
run_mode pic    "-relocation-model=pic" "-fpic" || rc=1
exit $rc
