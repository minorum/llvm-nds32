; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

declare i32 @external_func(i32, i32)

define i32 @call_external(i32 %a, i32 %b) {
; CHECK-LABEL: call_external:
; CHECK:      addi $r31, $r31, -8
; CHECK-NEXT: swi $r30, [$r31 + 4]
; CHECK-NEXT: jal external_func
; CHECK-NEXT: lwi $r30, [$r31 + 4]
; CHECK-NEXT: addi $r31, $r31, 8
; CHECK-NEXT: ret
entry:
  %result = call i32 @external_func(i32 %a, i32 %b)
  ret i32 %result
}

define i32 @call_with_args(i32 %x) {
; CHECK-LABEL: call_with_args:
; CHECK:      addi $r31, $r31, -8
; CHECK-NEXT: swi $r30, [$r31 + 4]
; CHECK:      jal external_func
; CHECK-NEXT: lwi $r30, [$r31 + 4]
; CHECK-NEXT: addi $r31, $r31, 8
; CHECK-NEXT: ret
entry:
  %result = call i32 @external_func(i32 %x, i32 %x)
  ret i32 %result
}
