; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

declare void @external_func(i32, i32, i32, i32, i32, i32)

define i32 @test_callee_saves(i32 %a, i32 %b) {
; CHECK-LABEL: test_callee_saves:
; CHECK:      addi	$r31, $r31, -32
; CHECK-NEXT:	swi	$r6, [$r31 + 28]
; CHECK-NEXT:	swi	$r7, [$r31 + 24]
; CHECK-NEXT:	swi	$r8, [$r31 + 20]
; CHECK-NEXT:	swi	$r9, [$r31 + 16]
; CHECK-NEXT:	swi	$r10, [$r31 + 12]
; CHECK-NEXT:	swi	$r11, [$r31 + 8]
; CHECK-NEXT:	swi	$r30, [$r31 + 4]
; CHECK:      jal	external_func
; CHECK:      jal	external_func
; CHECK:      lwi	$r30, [$r31 + 4]
; CHECK-NEXT:	lwi	$r11, [$r31 + 8]
; CHECK-NEXT:	lwi	$r10, [$r31 + 12]
; CHECK-NEXT:	lwi	$r9, [$r31 + 16]
; CHECK-NEXT:	lwi	$r8, [$r31 + 20]
; CHECK-NEXT:	lwi	$r7, [$r31 + 24]
; CHECK-NEXT:	lwi	$r6, [$r31 + 28]
; CHECK-NEXT:	addi	$r31, $r31, 32
; CHECK-NEXT:	ret
entry:
  call void @external_func(i32 %a, i32 %b, i32 3, i32 4, i32 5, i32 6)
  %add1 = add i32 %a, %b
  %add2 = add i32 %add1, 10
  call void @external_func(i32 %add1, i32 %add2, i32 3, i32 4, i32 5, i32 6)
  %res = add i32 %add1, %add2
  ret i32 %res
}
