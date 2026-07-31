; RUN: llc -mtriple=nds32be-unknown-none-elf -mcpu=v2 < %s \
; RUN:   | FileCheck %s --check-prefix=C16
; RUN: llc -mtriple=nds32be-unknown-none-elf -mcpu=v2 -mattr=-16bit-ext < %s \
; RUN:   | FileCheck %s --check-prefix=NO16
; RUN: llc -mtriple=nds32be-unknown-none-elf < %s \
; RUN:   | FileCheck %s --check-prefix=C16
;
; The Andes 16-bit extension is a positive subtarget feature ("16bit-ext",
; spelled as the Andes assembler spells it). Every processor model carries it,
; because every NDS32 baseline this backend targets implements it, so naming a
; CPU -- or naming none, which falls back to "generic" -- gets the compressed
; forms. That third RUN line is the one that matters for the rest of the suite:
; it pins the default, which is what lets every other test go on expecting
; compressed output without naming a CPU.
;
; Suppression is explicit and subtractive: "-16bit-ext". Cores configured
; without the 16-bit ISA fault on these encodings, so it must be exact -- the
; NDS32Compress pass has to not run at all.

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
