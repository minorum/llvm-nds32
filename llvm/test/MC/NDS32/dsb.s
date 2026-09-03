# RUN: llvm-mc -triple=nds32be-unknown-none-elf -show-encoding %s | FileCheck %s
#
# dsb: data synchronisation barrier (op6=0x32, sub=0x08 -- same MISC family as
# iret/syscall). Bytes match the MT6785 conn-MCU vendor ROM and the linked
# firmware.

# CHECK: dsb
# CHECK-SAME: encoding: [0x64,0x00,0x00,0x08]
dsb
