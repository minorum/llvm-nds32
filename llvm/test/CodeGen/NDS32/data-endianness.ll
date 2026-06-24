; Big-endian data emission. A regression guard for the bug where global
; initializers were serialized little-endian (MCAsmInfo::IsLittleEndian
; defaulted to true) even though nds32be is big-endian — silently byte-reversing
; every global. Checked at the object level because the .s form (`.word 100`)
; cannot reveal byte order. Found by running compiled code on the nds32 sim.

; RUN: llc -mtriple=nds32be-unknown-none-elf -filetype=obj < %s \
; RUN:   | llvm-objdump -s -j .data - | FileCheck %s --check-prefix=BE
; RUN: llc -mtriple=nds32le-unknown-none-elf -filetype=obj < %s \
; RUN:   | llvm-objdump -s -j .data - | FileCheck %s --check-prefix=LE

@g = global i32 100, align 4          ; 0x00000064
@h = global i32 305419896, align 4    ; 0x12345678

; BE:  0000 00000064 12345678
; LE:  0000 64000000 78563412
