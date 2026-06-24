; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

declare i32 @external_func(i32, i32)

define i32 @call_external(i32 %a, i32 %b) {
; CHECK-LABEL: call_external:
; CHECK:      addi $sp, $sp, -8
; CHECK-NEXT: swi $lp, [$sp + 4]
; CHECK-NEXT: jal external_func
; CHECK-NEXT: lwi $lp, [$sp + 4]
; CHECK-NEXT: addi $sp, $sp, 8
; CHECK-NEXT: ret
entry:
  %result = call i32 @external_func(i32 %a, i32 %b)
  ret i32 %result
}

define i32 @call_with_args(i32 %x) {
; CHECK-LABEL: call_with_args:
; CHECK:      addi $sp, $sp, -8
; CHECK-NEXT: swi $lp, [$sp + 4]
; CHECK:      jal external_func
; CHECK-NEXT: lwi $lp, [$sp + 4]
; CHECK-NEXT: addi $sp, $sp, 8
; CHECK-NEXT: ret
entry:
  %result = call i32 @external_func(i32 %x, i32 %x)
  ret i32 %result
}
