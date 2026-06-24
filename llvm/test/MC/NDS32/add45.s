# RUN: llvm-mc -triple=nds32be-unknown-none-elf -show-encoding %s | FileCheck %s
#
# add45/addi45 16-bit forms. $rt is a 4-bit field (r0-r11 -> 0-11,
# r16-r19 -> 12-15); the r16-r19 remap exercises the custom encoder. Encodings
# cross-checked byte-for-byte against the Andes assembler.

# CHECK: add45 $r0, $r1  ! encoding: [0x88,0x01]
add45 $r0, $r1
# CHECK: add45 $r11, $r5  ! encoding: [0x89,0x65]
add45 $r11, $r5
# CHECK: add45 $r16, $r31  ! encoding: [0x89,0x9f]
add45 $r16, $r31
# CHECK: addi45 $r0, 0  ! encoding: [0x8c,0x00]
addi45 $r0, 0
# CHECK: addi45 $r11, 31  ! encoding: [0x8d,0x7f]
addi45 $r11, 31
# CHECK: addi45 $r19, 1  ! encoding: [0x8d,0xe1]
addi45 $r19, 1
