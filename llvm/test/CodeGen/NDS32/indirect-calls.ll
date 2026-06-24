; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s
; RUN: llc -mtriple=nds32be-unknown-none-elf -filetype=obj < %s -o %t

define i32 @call_ptr1(ptr %f, i32 %x) {
; CHECK-LABEL: call_ptr1:
; CHECK:      addi $r31, $r31, -8
; CHECK-NEXT: swi $r30, [$r31 + 4]
; CHECK-NEXT: mov55 $r2, $r0
; CHECK-NEXT: mov55 $r0, $r1
; CHECK-NEXT: jral $r2
; CHECK-NEXT: lwi $r30, [$r31 + 4]
; CHECK-NEXT: addi $r31, $r31, 8
; CHECK-NEXT: ret
entry:
  %r = call i32 %f(i32 %x)
  ret i32 %r
}

define i32 @call_ptr2(ptr %f, i32 %x, i32 %y) {
; CHECK-LABEL: call_ptr2:
; CHECK:      mov55 $r3, $r0
; CHECK-NEXT: mov55 $r0, $r1
; CHECK-NEXT: mov55 $r1, $r2
; CHECK-NEXT: jral $r3
entry:
  %r = call i32 %f(i32 %x, i32 %y)
  ret i32 %r
}
