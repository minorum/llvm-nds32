; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

define i32 @select_ge_zero(i32 %x) {
; CHECK-LABEL: select_ge_zero:
; CHECK: bltz	$r0, .LBB0_2
; CHECK: movi55	$r0, 1
; CHECK: ret
; CHECK: movi55	$r0, 0
; CHECK: ret
entry:
  %c = icmp sgt i32 %x, -1
  br i1 %c, label %t, label %f

t:
  ret i32 1

f:
  ret i32 0
}

define i32 @select_lt_zero(i32 %x) {
; CHECK-LABEL: select_lt_zero:
; CHECK: bltz	$r0, .LBB1_1
; CHECK: movi55	$r0, 0
; CHECK: ret
; CHECK: .LBB1_1:
; CHECK: movi55	$r0, 1
; CHECK: ret
entry:
  %c = icmp slt i32 %x, 0
  br i1 %c, label %t, label %f

t:
  ret i32 1

f:
  ret i32 0
}

define i32 @select_gt_zero(i32 %x) {
; CHECK-LABEL: select_gt_zero:
; CHECK: blez	$r0, .LBB2_2
; CHECK: movi55	$r0, 1
; CHECK: ret
; CHECK: .LBB2_2:
; CHECK: movi55	$r0, 0
; CHECK: ret
entry:
  %c = icmp sgt i32 %x, 0
  br i1 %c, label %t, label %f

t:
  ret i32 1

f:
  ret i32 0
}

define i32 @select_le_zero(i32 %x) {
; CHECK-LABEL: select_le_zero:
; CHECK: bgtz	$r0, .LBB3_2
; CHECK: movi55	$r0, 1
; CHECK: ret
; CHECK: movi55	$r0, 0
; CHECK: ret
entry:
  %c = icmp sle i32 %x, 0
  br i1 %c, label %t, label %f

t:
  ret i32 1

f:
  ret i32 0
}

define i32 @select_slt_reg(i32 %a, i32 %b) {
; CHECK-LABEL: select_slt_reg:
; CHECK: slts	$r0, $r0, $r1
; CHECK: beqz38	$r0, .LBB4_2
; CHECK: movi55	$r0, 1
; CHECK: ret
; CHECK: .LBB4_2:
; CHECK: movi55	$r0, 0
; CHECK: ret
entry:
  %c = icmp slt i32 %a, %b
  br i1 %c, label %t, label %f

t:
  ret i32 1

f:
  ret i32 0
}

define i32 @select_ult_reg(i32 %a, i32 %b) {
; CHECK-LABEL: select_ult_reg:
; CHECK: slt	$r0, $r0, $r1
; CHECK: beqz38	$r0, .LBB5_2
; CHECK: movi55	$r0, 1
; CHECK: ret
; CHECK: .LBB5_2:
; CHECK: movi55	$r0, 0
; CHECK: ret
entry:
  %c = icmp ult i32 %a, %b
  br i1 %c, label %t, label %f

t:
  ret i32 1

f:
  ret i32 0
}
