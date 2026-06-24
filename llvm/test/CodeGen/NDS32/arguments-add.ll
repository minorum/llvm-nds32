; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

define i32 @id(i32 %x) {
; CHECK-LABEL: id:
; CHECK-NEXT: ! %bb.0:
; CHECK-NEXT: ret
  ret i32 %x
}

define i32 @add_const(i32 %x) {
; CHECK-LABEL: add_const:
; CHECK: addi333	$r0, $r0, 1
; CHECK-NEXT: ret
  %y = add i32 %x, 1
  ret i32 %y
}

define i32 @add2(i32 %a, i32 %b) {
; CHECK-LABEL: add2:
; CHECK: add	$r0, $r0, $r1
; CHECK-NEXT: ret
  %s = add i32 %a, %b
  ret i32 %s
}

define i32 @second(i32 %a, i32 %b) {
; CHECK-LABEL: second:
; CHECK: mov55	$r0, $r1
; CHECK-NEXT: ret
  ret i32 %b
}
