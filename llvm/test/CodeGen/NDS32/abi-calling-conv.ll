; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

; Andes ABI2: i64/f64 arguments occupy an EVEN-aligned register pair, consuming
; an odd register as padding. i32 args fill $r0-$r5 then 4-byte stack slots.
; Returns use $r0:$r1 (i64 high word in $r0).

; %a=$r0, %b=$r2:$r3 ($r1 is padding), %c=$r4.
define i32 @mixed(i32 %a, i64 %b, i32 %c) {
; CHECK-LABEL: mixed:
; CHECK: add	$r0, $r0, $r4
; CHECK: ret
  %r = add i32 %a, %c
  ret i32 %r
}

; %a,%b,%c=$r0,$r1,$r2, %d=$r4:$r5 ($r3 is padding); returned in $r0:$r1.
define i64 @oddalign(i32 %a, i32 %b, i32 %c, i64 %d) {
; CHECK-LABEL: oddalign:
; CHECK: addi	$r1, $r5, 0
; CHECK: addi	$r0, $r4, 0
; CHECK: ret
  ret i64 %d
}

; i64 return: high word in $r0, low word in $r1.
define i64 @retll() {
; CHECK-LABEL: retll:
; CHECK: movi	$r0, 287
; CHECK: movi	$r1, 1912276171
; CHECK: ret
  ret i64 1234567890123
}

; First six i32 args in registers, seventh on the stack.
define i32 @seven(i32 %a, i32 %b, i32 %c, i32 %d, i32 %e, i32 %f, i32 %g) {
; CHECK-LABEL: seven:
; CHECK: lwi	$r{{[0-9]+}}, [$r31 + 0]
; CHECK: ret
  ret i32 %g
}
