; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

declare void @external_func(i32, i32, i32, i32, i32, i32)

define i32 @test_callee_saves(i32 %a, i32 %b) {
; CHECK-LABEL: test_callee_saves:
; CHECK:      addi	$sp, $sp, -32
; CHECK-NEXT:	swi	$r6, [$sp + 28]
; CHECK-NEXT:	swi	$r7, [$sp + 24]
; CHECK-NEXT:	swi	$r8, [$sp + 20]
; CHECK-NEXT:	swi	$r9, [$sp + 16]
; CHECK-NEXT:	swi	$r10, [$sp + 12]
; CHECK-NEXT:	swi	$r11, [$sp + 8]
; CHECK-NEXT:	swi	$lp, [$sp + 4]
; CHECK:      jal	external_func
; CHECK:      jal	external_func
; CHECK:      lwi	$r6, [$sp + 28]
; CHECK-NEXT:	lwi	$r7, [$sp + 24]
; CHECK-NEXT:	lwi	$r8, [$sp + 20]
; CHECK-NEXT:	lwi	$r9, [$sp + 16]
; CHECK-NEXT:	lwi	$r10, [$sp + 12]
; CHECK-NEXT:	lwi	$r11, [$sp + 8]
; CHECK-NEXT:	lwi	$lp, [$sp + 4]
; CHECK-NEXT:	addi	$sp, $sp, 32
; CHECK-NEXT:	ret
entry:
  call void @external_func(i32 %a, i32 %b, i32 3, i32 4, i32 5, i32 6)
  %add1 = add i32 %a, %b
  %add2 = add i32 %add1, 10
  call void @external_func(i32 %add1, i32 %add2, i32 3, i32 4, i32 5, i32 6)
  %res = add i32 %add1, %add2
  ret i32 %res
}
