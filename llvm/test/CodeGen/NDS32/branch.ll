; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

define void @spin() {
; CHECK-LABEL: spin:
; CHECK: .LBB0_1:
; CHECK: b	.LBB0_1
entry:
  br label %loop

loop:
  br label %loop
}

define i32 @select_eq_zero(i32 %x) {
; CHECK-LABEL: select_eq_zero:
; CHECK: beqz	$r0, .LBB1_1
; CHECK: movi55	$r0, 0
; CHECK: ret
; CHECK: .LBB1_1:
; CHECK: movi55	$r0, 1
; CHECK: ret
entry:
  %c = icmp eq i32 %x, 0
  br i1 %c, label %t, label %f

t:
  ret i32 1

f:
  ret i32 0
}

define i32 @select_eq_pair(i32 %a, i32 %b) {
; CHECK-LABEL: select_eq_pair:
; CHECK: bne	$r0, $r1, .LBB2_2
; CHECK: movi55	$r0, 1
; CHECK: ret
; CHECK: .LBB2_2:
; CHECK: movi55	$r0, 0
; CHECK: ret
entry:
  %c = icmp eq i32 %a, %b
  br i1 %c, label %t, label %f

t:
  ret i32 1

f:
  ret i32 0
}
