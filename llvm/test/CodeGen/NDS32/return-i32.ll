; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

define i32 @zero() {
; CHECK-LABEL: zero:
; CHECK: movi	$r0, 0
; CHECK-NEXT: ret
  ret i32 0
}

define i32 @forty_two() {
; CHECK-LABEL: forty_two:
; CHECK: movi	$r0, 42
; CHECK-NEXT: ret
  ret i32 42
}
