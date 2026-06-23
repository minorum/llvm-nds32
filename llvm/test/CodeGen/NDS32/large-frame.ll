; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

; A stack frame larger than addi's signed 15-bit field must be allocated by
; materializing the size into the reserved scratch register ($r15) and adding by
; register, never by truncating the immediate.

; CHECK-LABEL: bigframe:
; CHECK: movi $r15, -80000
; CHECK: add $r31, $r31, $r15
; ... epilogue restores by the same amount ...
; CHECK: movi $r15, 80000
; CHECK: add $r31, $r31, $r15
; CHECK: ret
define i32 @bigframe() {
  %a = alloca [20000 x i32]
  %p = getelementptr [20000 x i32], ptr %a, i32 0, i32 19000
  store i32 3, ptr %p
  %r = load i32, ptr %p
  ret i32 %r
}

; A small frame still uses a single addi.
; CHECK-LABEL: smallframe:
; CHECK: addi $r31, $r31, -16
; CHECK: addi $r31, $r31, 16
define i32 @smallframe() {
  %a = alloca [4 x i32]
  %p = getelementptr [4 x i32], ptr %a, i32 0, i32 0
  store i32 3, ptr %p
  %r = load i32, ptr %p
  ret i32 %r
}
