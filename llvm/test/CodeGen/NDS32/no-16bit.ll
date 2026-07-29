; RUN: llc -mtriple=nds32be-unknown-none-elf -mcpu=v2 < %s \
; RUN:   | FileCheck %s --check-prefix=C16
; RUN: llc -mtriple=nds32be-unknown-none-elf -mcpu=v2 -mattr=+no-16bit < %s \
; RUN:   | FileCheck %s --check-prefix=NO16
;
; "+no-16bit" suppresses the 16-bit (compressed) forms entirely: the
; NDS32Compress pass must not run. Cores configured without the 16-bit ISA fault
; on these encodings.

define i32 @f(i32 %a, i32 %b) {
; C16: f:
; C16: add45
; C16: addi45
;
; NO16: f:
; NO16: add $r0, $r0, $r1
; NO16: addi $r0, $r0, 8
; NO16-NOT: add45
; NO16-NOT: addi45
; NO16-NOT: movi55
  %s = add i32 %a, 1
  %t = add i32 %s, %b
  %u = shl i32 %t, 3
  ret i32 %u
}
