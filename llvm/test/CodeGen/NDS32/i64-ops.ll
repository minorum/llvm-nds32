; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

; i64 is legalized into i32 register pairs. For nds32be the high word lives in
; the lower-numbered register and at the lower address.

; Subtraction propagates a borrow computed with an unsigned "slt".
define i64 @sub64(i64 %a, i64 %b) {
; CHECK-LABEL: sub64:
; CHECK:      sub	$r0, $r0, $r2
; CHECK-NEXT: slt	$r2, $r1, $r3
; CHECK-NEXT: sub	$r0, $r0, $r2
; CHECK-NEXT: sub	$r1, $r1, $r3
; CHECK-NEXT: ret
  %r = sub i64 %a, %b
  ret i64 %r
}

; Bitwise ops are independent per word.
define i64 @and64(i64 %a, i64 %b) {
; CHECK-LABEL: and64:
; CHECK:      and	$r0, $r0, $r2
; CHECK-NEXT: and	$r1, $r1, $r3
; CHECK-NEXT: ret
  %r = and i64 %a, %b
  ret i64 %r
}

; Full 64x64 multiply has no hardware support, so it becomes a libcall.
define i64 @mul64(i64 %a, i64 %b) {
; CHECK-LABEL: mul64:
; CHECK: jal	__muldi3
; CHECK: ret
  %r = mul i64 %a, %b
  ret i64 %r
}

; Variable-distance i64 shift is also a libcall.
define i64 @shl64(i64 %a, i64 %b) {
; CHECK-LABEL: shl64:
; CHECK: jal	__ashldi3
; CHECK: ret
  %r = shl i64 %a, %b
  ret i64 %r
}

; Loads/stores split into two words; the high word is at the lower offset.
define i64 @ld64(ptr %p) {
; CHECK-LABEL: ld64:
; CHECK:      lwi	$r2, [$r0 + 0]
; CHECK-NEXT: lwi	$r1, [$r0 + 4]
; CHECK-NEXT: addi	$r0, $r2, 0
; CHECK-NEXT: ret
  %r = load i64, ptr %p
  ret i64 %r
}

define void @st64(ptr %p, i64 %v) {
; CHECK-LABEL: st64:
; CHECK:      swi	$r1, [$r0 + 0]
; CHECK-NEXT: swi	$r2, [$r0 + 4]
; CHECK-NEXT: ret
  store i64 %v, ptr %p
  ret void
}

; Signed i64 compare: equal high words fall back to an unsigned low-word
; compare, otherwise a signed high-word compare. The high-word equality test
; is a local forward bnez.
define i32 @slt64(i64 %a, i64 %b) {
; CHECK-LABEL: slt64:
; CHECK:      slt	{{.*}}
; CHECK:      bnez	{{.*}}
; CHECK:      slts	$r0, $r0, $r2
; CHECK:      ret
; CHECK:      slt	$r0, $r1, $r3
; CHECK:      ret
  %c = icmp slt i64 %a, %b
  %z = zext i1 %c to i32
  ret i32 %z
}
