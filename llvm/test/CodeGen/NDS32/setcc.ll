; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

; Integer SETCC producing an i32 0/1 result for every condition code. The
; hardware only has signed/unsigned "set less than" (slts/slt), so every other
; predicate is synthesized from those, optionally inverting with "xori .., 1".

define i32 @setcc_eq(i32 %a, i32 %b) {
; CHECK-LABEL: setcc_eq:
; CHECK: xor	$r0, $r0, $r1
; CHECK: movi	$r1, 0
; CHECK: slt	$r0, $r1, $r0
; CHECK: xori	$r0, $r0, 1
; CHECK: ret
  %c = icmp eq i32 %a, %b
  %z = zext i1 %c to i32
  ret i32 %z
}

define i32 @setcc_ne(i32 %a, i32 %b) {
; CHECK-LABEL: setcc_ne:
; CHECK: xor	$r0, $r0, $r1
; CHECK: movi	$r1, 0
; CHECK: slt	$r0, $r1, $r0
; CHECK: ret
  %c = icmp ne i32 %a, %b
  %z = zext i1 %c to i32
  ret i32 %z
}

define i32 @setcc_slt(i32 %a, i32 %b) {
; CHECK-LABEL: setcc_slt:
; CHECK: slts	$r0, $r0, $r1
; CHECK: ret
  %c = icmp slt i32 %a, %b
  %z = zext i1 %c to i32
  ret i32 %z
}

define i32 @setcc_sgt(i32 %a, i32 %b) {
; CHECK-LABEL: setcc_sgt:
; CHECK: slts	$r0, $r1, $r0
; CHECK: ret
  %c = icmp sgt i32 %a, %b
  %z = zext i1 %c to i32
  ret i32 %z
}

define i32 @setcc_sge(i32 %a, i32 %b) {
; CHECK-LABEL: setcc_sge:
; CHECK: slts	$r0, $r0, $r1
; CHECK: xori	$r0, $r0, 1
; CHECK: ret
  %c = icmp sge i32 %a, %b
  %z = zext i1 %c to i32
  ret i32 %z
}

define i32 @setcc_sle(i32 %a, i32 %b) {
; CHECK-LABEL: setcc_sle:
; CHECK: slts	$r0, $r1, $r0
; CHECK: xori	$r0, $r0, 1
; CHECK: ret
  %c = icmp sle i32 %a, %b
  %z = zext i1 %c to i32
  ret i32 %z
}

define i32 @setcc_ult(i32 %a, i32 %b) {
; CHECK-LABEL: setcc_ult:
; CHECK: slt	$r0, $r0, $r1
; CHECK: ret
  %c = icmp ult i32 %a, %b
  %z = zext i1 %c to i32
  ret i32 %z
}

define i32 @setcc_ugt(i32 %a, i32 %b) {
; CHECK-LABEL: setcc_ugt:
; CHECK: slt	$r0, $r1, $r0
; CHECK: ret
  %c = icmp ugt i32 %a, %b
  %z = zext i1 %c to i32
  ret i32 %z
}

define i32 @setcc_uge(i32 %a, i32 %b) {
; CHECK-LABEL: setcc_uge:
; CHECK: slt	$r0, $r0, $r1
; CHECK: xori	$r0, $r0, 1
; CHECK: ret
  %c = icmp uge i32 %a, %b
  %z = zext i1 %c to i32
  ret i32 %z
}

define i32 @setcc_ule(i32 %a, i32 %b) {
; CHECK-LABEL: setcc_ule:
; CHECK: slt	$r0, $r1, $r0
; CHECK: xori	$r0, $r0, 1
; CHECK: ret
  %c = icmp ule i32 %a, %b
  %z = zext i1 %c to i32
  ret i32 %z
}
