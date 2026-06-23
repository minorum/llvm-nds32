; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s
; RUN: llc -mtriple=nds32be-unknown-none-elf -filetype=obj < %s -o %t

define i32 @sdiv32(i32 %a, i32 %b) {
; CHECK-LABEL: sdiv32:
; CHECK:      divsr $r0, $r1, $r0, $r1
; CHECK-NEXT: ret
entry:
  %q = sdiv i32 %a, %b
  ret i32 %q
}

define i32 @udiv32(i32 %a, i32 %b) {
; CHECK-LABEL: udiv32:
; CHECK:      divr $r0, $r1, $r0, $r1
; CHECK-NEXT: ret
entry:
  %q = udiv i32 %a, %b
  ret i32 %q
}

define i32 @srem32(i32 %a, i32 %b) {
; CHECK-LABEL: srem32:
; CHECK:      divsr $r1, $r0, $r0, $r1
; CHECK-NEXT: ret
entry:
  %r = srem i32 %a, %b
  ret i32 %r
}

define i32 @urem32(i32 %a, i32 %b) {
; CHECK-LABEL: urem32:
; CHECK:      divr $r1, $r0, $r0, $r1
; CHECK-NEXT: ret
entry:
  %r = urem i32 %a, %b
  ret i32 %r
}
