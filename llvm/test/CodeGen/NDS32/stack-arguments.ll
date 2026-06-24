; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

declare void @callee8(i32, i32, i32, i32, i32, i32, i32, i32)

define void @call_stack_args() {
; CHECK-LABEL: call_stack_args:
; CHECK:      addi	$r31, $r31, -16
; CHECK-NEXT:	swi	$r30, [$r31 + 12]
; CHECK-NEXT:	movi55	$r0, 8
; CHECK-NEXT:	swi	$r0, [$r31 + 4]
; CHECK-NEXT:	movi55	$r0, 7
; CHECK-NEXT:	swi	$r0, [$r31 + 0]
; CHECK:      jal	callee8
; CHECK-NEXT:	lwi	$r30, [$r31 + 12]
; CHECK-NEXT:	addi	$r31, $r31, 16
; CHECK-NEXT:	ret
entry:
  call void @callee8(i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8)
  ret void
}

define i32 @incoming_stack_args(i32 %a0, i32 %a1, i32 %a2, i32 %a3,
                                i32 %a4, i32 %a5, i32 %a6, i32 %a7) {
; CHECK-LABEL: incoming_stack_args:
; CHECK:      lwi	$r0, [$r31 + 4]
; CHECK-NEXT:	lwi	$r1, [$r31 + 0]
; CHECK-NEXT:	add45	$r0, $r1
; CHECK-NEXT:	ret
entry:
  %sum = add i32 %a6, %a7
  ret i32 %sum
}
