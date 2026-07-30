#!/usr/bin/env bash
# Build the Andes nds32 instruction-set simulator (`nds32be-elf-run`).
#
# Upstream GNU `sim` never had an nds32 target, and current Andes forks are
# RISC-V only. The nds32 (AndeStar V3) sim lives in the Andes gdb fork on the
# legacy V3 branch. This builds just the standalone runner (no gdb), which
# supports newlib/libgloss semihosting (exit/read/write syscalls) — enough to
# run a bare-metal ELF and read its exit code.
#
# Output: $DEST/sim/nds32/run   (invoke as: run prog.elf ; echo $?)
set -euo pipefail

DEST=${1:-/home/dministrator/nds32be-build/nds32-gdb-sim}
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
