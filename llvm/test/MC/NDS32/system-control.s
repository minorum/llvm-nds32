# RUN: llvm-mc -triple=nds32be-unknown-none-elf -show-encoding %s | FileCheck %s

# System-control forms used by the ConnMCU mask ROM and replacement firmware.

# CHECK: isb                              ! encoding: [0x64,0x00,0x00,0x09]
isb

# CHECK: setgie.d                         ! encoding: [0x64,0x02,0x00,0x43]
setgie.d

# CHECK: setgie.e                         ! encoding: [0x64,0x12,0x00,0x43]
setgie.e

# Exercise all four architected standby-state encodings, including the
# `wait_done`/2 form used by ConnMCU.
# CHECK: standby 0                        ! encoding: [0x64,0x00,0x00,0x00]
standby 0
# CHECK: standby 1                        ! encoding: [0x64,0x00,0x00,0x20]
standby 1
# CHECK: standby 2                        ! encoding: [0x64,0x00,0x00,0x40]
standby 2
# CHECK: standby 3                        ! encoding: [0x64,0x00,0x00,0x60]
standby 3

# Check both ends of break16's five-bit exception-number field.
# CHECK: break16 0                        ! encoding: [0xea,0x00]
break16 0
# CHECK: break16 31                       ! encoding: [0xea,0x1f]
break16 31
