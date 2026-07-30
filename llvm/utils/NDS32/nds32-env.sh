# shellcheck shell=bash
# ===----------------------------------------------------------------------===##
#
# Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
# ===----------------------------------------------------------------------===##
# Shared tool resolution for the NDS32 helper scripts. Source, do not execute.
#
# Nothing here encodes a particular developer's directory layout. Each tool is
# taken from its environment variable if set, else from PATH, else the script
# stops with a message naming the variable to set. The nds32-llvm workspace's
# env.sh exports exactly these names ($TC, $SIM, $LLC, $OBJDUMP), so sourcing it
# makes every one of them resolve; equally, a bare `PATH=/opt/nds32/bin:$PATH`
# is enough on its own.

# Absolute directory of the calling script. Usage: HERE=$(nds32_here "$0")
nds32_here() { cd "$(dirname "$1")" && pwd; }

# The fork's own build tree, derived from this file's location
# (llvm/utils/NDS32 -> repository root). Not a guess about anyone's machine.
nds32_build_bin() { echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/build/bin"; }

# $TC = the Andes nds32be-elf toolchain's bin directory.
#
# Usage: nds32_need_tc nds32be-elf-ld [more tools...]
# Name the tools the calling script actually invokes. A toolchain build can be
# binutils-only (no nds32be-elf-gcc), which is fine for linking but not for the
# execution tests -- probing for a fixed tool would either reject a usable
# install or fail later with a confusing error.
nds32_need_tc() {
  local probe=${1:-nds32be-elf-ld} t
  if [ -z "${TC:-}" ] && command -v "$probe" >/dev/null 2>&1; then
    TC=$(dirname "$(command -v "$probe")")
  fi
  if [ -z "${TC:-}" ]; then
    echo "error: Andes nds32be-elf toolchain not found." >&2
    echo "       Set TC=/path/to/toolchain/bin, or put $probe on PATH." >&2
    exit 1
  fi
  for t in "$@"; do
    if [ ! -x "$TC/$t" ]; then
      echo "error: $t not found under TC=$TC" >&2
      echo "       This script needs: $*" >&2
      exit 1
    fi
  done
  export TC
}

# $CARGO: prefer the rustup shim over whatever `cargo` is on PATH. These builds
# need a nightly toolchain (-Z build-std, -Z json-target-spec); a distro cargo is
# typically stable and would fail well after the point of confusion.
nds32_need_cargo() {
  if [ -z "${CARGO:-}" ]; then
    if [ -x "$HOME/.cargo/bin/cargo" ]; then
      CARGO=$HOME/.cargo/bin/cargo
    else
      CARGO=$(command -v cargo || true)
    fi
  fi
  if [ -z "$CARGO" ] || [ ! -x "$CARGO" ]; then
    echo "error: cargo not found. Set CARGO=/path/to/cargo (a nightly toolchain is required)." >&2
    exit 1
  fi
  export CARGO
}

# $RUN = the nds32 ISS. $SIM is the nds32-llvm workspace's name for it; accept
# both, preferring an explicit $RUN.
nds32_need_run() {
  RUN=${RUN:-${SIM:-}}
  if [ -z "$RUN" ] && command -v nds32be-elf-run >/dev/null 2>&1; then
    RUN=$(command -v nds32be-elf-run)
  fi
  if [ -z "$RUN" ] || [ ! -x "$RUN" ]; then
    echo "error: nds32 simulator not found." >&2
    echo "       Set SIM=/path/to/sim/nds32/run (build it with build-nds32-sim.sh)." >&2
    [ -n "$RUN" ] && echo "       (tried: $RUN)" >&2
    exit 1
  fi
  export RUN
}

# $LLC / $OBJDUMP default to THIS fork's build, never to PATH: a system llc or
# llvm-objdump has no NDS32 target, and silently using one is precisely the
# wrong-tool substitution this project has already lost days to.
nds32_need_llc() {
  LLC=${LLC:-$(nds32_build_bin)/llc}
  if [ ! -x "$LLC" ]; then
    echo "error: llc not found at $LLC" >&2
    echo "       Build it (make -C build llc) or set LLC=/path/to/llc." >&2
    exit 1
  fi
  export LLC
}

nds32_need_objdump() {
  OD=${OD:-${OBJDUMP:-$(nds32_build_bin)/llvm-objdump}}
  if [ ! -x "$OD" ]; then
    echo "error: llvm-objdump not found at $OD" >&2
    echo "       Build it (make -C build llvm-objdump) or set OBJDUMP=/path/to/llvm-objdump." >&2
    exit 1
  fi
  export OD
}
