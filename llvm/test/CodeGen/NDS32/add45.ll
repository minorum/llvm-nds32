; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s
;
; The 16-bit add45/addi45 compressed forms: add45 is "$rt += $rb" (tied), addi45
; is "$rt += imm5u". Both restrict $rt to the 4-bit register subset (r0-r11,
; r16-r19) and addi45's immediate to [0,31].

; add $r0, $r0, $r1  ->  add45 $r0, $r1  (rt == one source, in the subset)
; CHECK-LABEL: addreg:
; CHECK: add45 $r0, $r1
; CHECK-NEXT: ret
define i32 @addreg(i32 %a, i32 %b) {
  %s = add i32 %a, %b
  ret i32 %s
}

; add $rt, $rt, imm with imm in [8,31] -> addi45 (imm in [0,7] prefers addi333).
; CHECK-LABEL: inc20:
; CHECK: addi45 $r0, 20
; CHECK-NEXT: ret
define i32 @inc20(i32 %x) {
  %s = add i32 %x, 20
  ret i32 %s
}

; imm just past the 5-bit range stays the 32-bit immediate form.
; CHECK-LABEL: inc32:
; CHECK: addi $r0, $r0, 32
; CHECK-NEXT: ret
define i32 @inc32(i32 %x) {
  %s = add i32 %x, 32
  ret i32 %s
}
