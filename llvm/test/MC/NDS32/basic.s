# RUN: llvm-mc -triple=nds32be-unknown-none-elf -show-encoding %s | FileCheck %s

# CHECK: add $r1, $r0, $r2  ! encoding: [0x40,0x10,0x08,0x00]
add $r1, $r0, $r2
# CHECK: addi $r5, $r6, 100  ! encoding: [0x50,0x53,0x00,0x64]
addi $r5, $r6, 100
# CHECK: movi $r0, 1000  ! encoding: [0x44,0x00,0x03,0xe8]
movi $r0, 1000
# CHECK: mov $r0, $r1
mov $r0, $r1
# CHECK: lwi $r0, [$r1 + 4]  ! encoding: [0x04,0x00,0x80,0x01]
lwi $r0, [$r1 + 4]
# CHECK: swi $r2, [$r3 + 0]  ! encoding: [0x14,0x21,0x80,0x00]
swi $r2, [$r3]
# CHECK: lw $r0, [$r1 + $r2 << 2]  ! encoding: [0x38,0x00,0x8a,0x02]
lw $r0, [$r1 + $r2 << 2]
