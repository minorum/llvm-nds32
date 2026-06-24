; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

; ISD::SELECT / ISD::SELECT_CC are lowered branchlessly: the condition is
; materialized into a register, then the two values are merged with a pair of
; conditional moves (cmovn picks the true value when the condition is nonzero,
; cmovz picks the false value when the condition is zero).

define i32 @select_slt(i32 %a, i32 %b, i32 %c) {
; CHECK-LABEL: select_slt:
; CHECK: slts	$r3, $r0, $r1
; CHECK: cmovn	$r0, $r1, $r3
; CHECK: cmovz	$r0, $r2, $r3
; CHECK: ret
  %cmp = icmp slt i32 %a, %b
  %r = select i1 %cmp, i32 %b, i32 %c
  ret i32 %r
}

define i32 @select_bool(i1 %cond, i32 %a, i32 %b) {
; CHECK-LABEL: select_bool:
; CHECK: andi	$r3, $r0, 1
; CHECK: cmovn	$r0, $r1, $r3
; CHECK: cmovz	$r0, $r2, $r3
; CHECK: ret
  %r = select i1 %cond, i32 %a, i32 %b
  ret i32 %r
}

define i32 @select_eq_const(i32 %a, i32 %b) {
; CHECK-LABEL: select_eq_const:
; CHECK: xor	$r0, $r0, $r1
; CHECK: movi55	$r1, 0
; CHECK: slt	$r0, $r1, $r0
; CHECK: xori	$r1, $r0, 1
; CHECK: movi	$r2, 200
; CHECK: movi	$r0, 100
; CHECK: cmovn	$r0, $r0, $r1
; CHECK: cmovz	$r0, $r2, $r1
; CHECK: ret
  %cmp = icmp eq i32 %a, %b
  %r = select i1 %cmp, i32 100, i32 200
  ret i32 %r
}
