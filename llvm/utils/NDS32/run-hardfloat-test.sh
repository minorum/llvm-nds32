#!/usr/bin/env bash
# ===----------------------------------------------------------------------===##
#
# Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# ===----------------------------------------------------------------------===##
# End-to-end EXECUTION test of the HARD-FLOAT ABI (Andes 2fp+): our llc compiles
# ours_hf.ll with -mcpu=v3f-hard (single-precision floats in $fs registers), an
# Andes-gcc hard-float main calls those functions across the real ABI, and the
# whole thing runs on the nds32 sim. This verifies that f32 args/returns travel
# in FP registers exactly where gcc expects them (and back), with no fmtsr/fmfsr
# boxing at call boundaries.
#
# Toolchain note: the bundled gas predates the 2fp+ ABI tag GCC 13.3 emits, so
# the gcc side is assembled in two steps -- compile to .s, strip the
# `.abi_2fp_plus` ELF-attribute directive (cosmetic; the instructions already use
# the hard-float registers), then assemble with `as -mfpu-sp-ext` (which avoids
# the gcc driver's unsupported ABI flag). Linking uses the gcc driver normally.
#
# Prereqs: build the sim once with scripts/build-nds32-sim.sh.
set -euo pipefail
cd "$(dirname "$0")/exec-test/hardfloat"

LLC=${LLC:-/home/dministrator/nds32-llvm/llvm22/build/bin/llc}
TC=${TC:-/home/dministrator/nds32be-build/toolchain/bin}
RUN=${RUN:-/home/dministrator/nds32be-build/nds32-gdb-sim/build-sim/sim/nds32/run}
TRIPLE=nds32be-unknown-none-elf

# 1. our functions, hard-float ABI
"$LLC" -mtriple=$TRIPLE -mcpu=v3f-hard -filetype=obj ours_hf.ll -o ours_hf.o

# 2. gcc hard-float main: compile -> strip abi tag -> assemble with `as`
"$TC/nds32be-elf-gcc" -O2 -mbig-endian -march=v3 -mext-fpu-sp -mfloat-abi=hard \
  -S main_hf.c -o main_hf.s
grep -vE '^[[:space:]]*\.abi_2fp_plus' main_hf.s > main_hf.stripped.s
"$TC/nds32be-elf-as" -march=v3 -mfpu-sp-ext main_hf.stripped.s -o main_hf.o

# 3. link (driver does linking only here, so no unsupported ABI flag reaches as)
"$TC/nds32be-elf-gcc" -mbig-endian -march=v3 -mext-fpu-sp -mfloat-abi=hard \
  main_hf.o ours_hf.o -o test_hf.elf -Wl,--no-warn-mismatch 2>/dev/null

set +e; "$RUN" test_hf.elf >/tmp/hf.out 2>/dev/null; code=$?; set -e
cat /tmp/hf.out
if [ "$code" -eq 0 ]; then echo "HARD-FLOAT EXEC TEST PASS"; exit 0; fi
echo "HARD-FLOAT EXEC TEST FAIL (exit $code = failing-check count)"; exit 1
