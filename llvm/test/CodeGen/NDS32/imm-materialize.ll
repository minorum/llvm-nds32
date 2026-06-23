; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

; Immediates are materialized within each instruction's real encoded width.
; movi holds a signed 20-bit value; wider constants use sethi(hi20)+ori(lo12);
; an immediate too wide for an instruction's field is built in a register and
; the register-form op is used (never silently truncated).

; CHECK-LABEL: c20bit:
; CHECK: movi $r0, 100000
define i32 @c20bit() { ret i32 100000 }

; CHECK-LABEL: cwide:
; CHECK: sethi $r0, 74565
; CHECK: ori $r0, $r0, 1656
define i32 @cwide() { ret i32 305419896 } ; 0x12345678 = (0x12345<<12)|0x678

; addi is signed 15-bit; a wider addend is materialized then added by register.
; CHECK-LABEL: addwide:
; CHECK: movi $r1, 100000
; CHECK: add $r0, $r0, $r1
define i32 @addwide(i32 %x) {
  %r = add i32 %x, 100000
  ret i32 %r
}

; An in-range addend still uses the immediate form.
; CHECK-LABEL: addsmall:
; CHECK: addi $r0, $r0, 100
define i32 @addsmall(i32 %x) {
  %r = add i32 %x, 100
  ret i32 %r
}

; ori is unsigned 15-bit; a wider mask is materialized then or'd by register.
; CHECK-LABEL: orwide:
; CHECK: or $r0, $r0, $r1
define i32 @orwide(i32 %x) {
  %r = or i32 %x, 100000
  ret i32 %r
}
