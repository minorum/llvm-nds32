; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

; ISD::SELECT / ISD::SELECT_CC are lowered to a control-flow diamond by the
; Select pseudo's custom inserter: branch on the condition with bnez, then
; merge the two values with a PHI.

define i32 @select_slt(i32 %a, i32 %b, i32 %c) {
; CHECK-LABEL: select_slt:
; CHECK: slts	$r1, {{.*}}
; CHECK: bnez	$r1, .LBB0_2
; CHECK: .LBB0_2:
; CHECK: ret
  %cmp = icmp slt i32 %a, %b
  %r = select i1 %cmp, i32 %b, i32 %c
  ret i32 %r
}

define i32 @select_bool(i1 %cond, i32 %a, i32 %b) {
; CHECK-LABEL: select_bool:
; CHECK: andi	$r3, $r0, 1
; CHECK: bnez	$r3, .LBB1_2
; CHECK: .LBB1_2:
; CHECK: ret
  %r = select i1 %cond, i32 %a, i32 %b
  ret i32 %r
}

define i32 @select_eq_const(i32 %a, i32 %b) {
; CHECK-LABEL: select_eq_const:
; CHECK: bnez	$r0, .LBB2_1
; CHECK: movi	$r0, 200
; CHECK: ret
; CHECK: .LBB2_1:
; CHECK: movi	$r0, 100
; CHECK: ret
  %cmp = icmp eq i32 %a, %b
  %r = select i1 %cmp, i32 100, i32 200
  ret i32 %r
}
