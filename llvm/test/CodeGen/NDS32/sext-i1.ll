; sign_extend_inreg from i1 has no NDS32 instruction. It must be expanded
; (not crash ISel with "Cannot select: sign_extend_inreg ... i1"). This pattern
; — sign-extending the result of a boolean NOT — was hit compiling Rust's
; compiler_builtins; the whole crate failed to compile before the fix.

; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

; sext(not(bit)) == (bit & 1) - 1 : bit=0 -> -1, bit=1 -> 0.
define i32 @sext_not(i32 %a, i32 %b) {
; CHECK-LABEL: sext_not:
; CHECK:      andi $r{{[0-9]+}}, $r{{[0-9]+}}, 1
; CHECK:      addi $r{{[0-9]+}}, $r{{[0-9]+}}, -1
; CHECK:      ret
  %x = lshr i32 %a, %b
  %t = trunc i32 %x to i1
  %n = xor i1 %t, true
  %s = sext i1 %n to i32
  ret i32 %s
}

; sext of a comparison result (0 or -1).
define i32 @sext_cmp(i32 %x, i32 %y) {
; CHECK-LABEL: sext_cmp:
; CHECK:      ret
  %c = icmp ult i32 %x, %y
  %s = sext i1 %c to i32
  ret i32 %s
}
