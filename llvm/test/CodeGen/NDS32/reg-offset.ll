; RUN: llc -mtriple=nds32be-unknown-none-elf -verify-machineinstrs < %s | FileCheck %s

; Indexed accesses use the register-offset addressing mode lw [$ra + $rb << sv]
; in a single instruction instead of an explicit shift + add.

; CHECK-LABEL: load_word:
; CHECK: lw $r{{[0-9]+}}, [$r{{[0-9]+}} + $r{{[0-9]+}} << 2]
define i32 @load_word(ptr %a, i32 %i) {
  %p = getelementptr i32, ptr %a, i32 %i
  %v = load i32, ptr %p
  ret i32 %v
}

; CHECK-LABEL: store_word:
; CHECK: sw $r{{[0-9]+}}, [$r{{[0-9]+}} + $r{{[0-9]+}} << 2]
define void @store_word(ptr %a, i32 %i, i32 %x) {
  %p = getelementptr i32, ptr %a, i32 %i
  store i32 %x, ptr %p
  ret void
}

; A byte index needs no scaling (scale 0).
; CHECK-LABEL: load_byte:
; CHECK: lb $r{{[0-9]+}}, [$r{{[0-9]+}} + $r{{[0-9]+}}]
define signext i8 @load_byte(ptr %a, i32 %i) {
  %p = getelementptr i8, ptr %a, i32 %i
  %v = load i8, ptr %p
  ret i8 %v
}
