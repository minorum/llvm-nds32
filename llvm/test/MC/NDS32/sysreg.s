# RUN: llvm-mc -triple=nds32be-unknown-none-elf -mcpu=v3 -show-encoding %s | FileCheck %s
#
# System-register moves (mfsr/mtsr) -- NOT the floating-point fmfsr/fmtsr, which
# are a different opcode. Every encoding below was taken from the Andes
# nds32be-elf-as output for the same source line; the full 273-spelling
# differential check lives in scripts/verify-sysregs.py.
#
# Field layout: opcode bits[31:25] = 0x32, rt = bits[24:20],
# SRIDX = bits[19:5], sub-opcode bits[4:0] = 2 (mfsr) / 3 (mtsr).

# CHECK: mfsr $r0, $psw  ! encoding: [0x64,0x02,0x00,0x02]
mfsr $r0, $psw
# CHECK: mtsr $r0, $psw  ! encoding: [0x64,0x02,0x00,0x03]
mtsr $r0, $psw

# rt is encoded, not fixed.
# CHECK: mfsr $r5, $ipc  ! encoding: [0x64,0x52,0xa4,0x02]
mfsr $r5, $ipc
# CHECK: mtsr $r5, $ipc  ! encoding: [0x64,0x52,0xa4,0x03]
mtsr $r5, $ipc

# The breakpoint/debug registers the MT6785 conn-MCU firmware writes.
# CHECK: mtsr $r0, $bpc0  ! encoding: [0x64,0x06,0x00,0x03]
mtsr $r0, $bpc0
# CHECK: mtsr $r0, $bpc6  ! encoding: [0x64,0x06,0x18,0x03]
mtsr $r0, $bpc6
# CHECK: mtsr $r0, $bpa0  ! encoding: [0x64,0x06,0x20,0x03]
mtsr $r0, $bpa0
# CHECK: mtsr $r0, $bpam0  ! encoding: [0x64,0x06,0x40,0x03]
mtsr $r0, $bpam0
# CHECK: mtsr $r0, $bpv0  ! encoding: [0x64,0x06,0x60,0x03]
mtsr $r0, $bpv0
# CHECK: mtsr $r0, $edm_ctl  ! encoding: [0x64,0x06,0xe0,0x03]
mtsr $r0, $edm_ctl

# Alias spellings binutils accepts ($crN/$irN/$drN) are ACCEPTED on input and
# encode identically to the name they alias. On this asm->asm path the alias is
# echoed back, because each alias is its own register def and the InstPrinter
# prints whichever register the parser produced. Canonicalisation is a property
# of the *disassembly* path only (bytes -> MCInst picks the canonical name); that
# direction is covered by scripts/verify-sysregs.py's round-trip check.
# CHECK: mtsr $r0, $ir0  ! encoding: [0x64,0x02,0x00,0x03]
mtsr $r0, $ir0
# CHECK: mtsr $r0, $dr0  ! encoding: [0x64,0x06,0x00,0x03]
mtsr $r0, $dr0
# $cr0 aliases $cpu_ver, which is SRIDX 0 -- so the SRIDX field is all zero here
# (binutils: "64 00 00 02"), not $psw's 0x1000.
# CHECK: mfsr $r0, $cr0  ! encoding: [0x64,0x00,0x00,0x02]
mfsr $r0, $cr0
