#!/usr/bin/env bash
# ===----------------------------------------------------------------------===##
#
# Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# ===----------------------------------------------------------------------===##
# Build the Andes nds32 instruction-set simulator (`nds32be-elf-run`).
#
# Upstream GNU `sim` never had an nds32 target, and current Andes forks are
# RISC-V only. The nds32 (AndeStar V3) sim lives in the Andes gdb fork on the
# legacy V3 branch. This builds just the standalone runner (no gdb), which
# supports newlib/libgloss semihosting (exit/read/write syscalls) — enough to
# run a bare-metal ELF and read its exit code.
#
# Output: $DEST/build-sim/sim/nds32/run   (invoke as: run prog.elf ; echo $?)
#
# Destination, in order: the first argument; else the tree implied by $SIM (the
# nds32-llvm workspace exports it, so a rebuild lands where everything already
# looks for it); else ./nds32-gdb-sim under the current directory. No developer's
# layout is assumed -- pass an argument to put it anywhere.
set -euo pipefail

if [ -n "${1:-}" ]; then
  DEST=$1
elif [ -n "${SIM:-}" ]; then
  DEST=${SIM%/build-sim/sim/nds32/run}
  [ "$DEST" != "$SIM" ] || DEST=$PWD/nds32-gdb-sim
else
  DEST=$PWD/nds32-gdb-sim
fi
echo "Building into: $DEST"
BRANCH=ast-v3_2_5-release-v3   # AndeStar V3 = nds32

if [ ! -d "$DEST" ]; then
  git clone --depth 1 --branch "$BRANCH" --single-branch \
    https://github.com/andestech/gdb.git "$DEST"
fi

mkdir -p "$DEST/build-sim"
cd "$DEST/build-sim"
[ -f Makefile ] || ../configure --target=nds32be-elf \
  --enable-sim --disable-gdb --disable-binutils --disable-gas --disable-ld \
  --disable-gold --disable-gprof --disable-gdbserver --disable-libdecnumber \
  --disable-readline --disable-werror --disable-nls

# MAKEINFO=true: the 2016-era tree builds bfd docs in `all`; no makeinfo needed.
make all-sim -j3 MAKEINFO=true

echo "Built: $DEST/build-sim/sim/nds32/run"
