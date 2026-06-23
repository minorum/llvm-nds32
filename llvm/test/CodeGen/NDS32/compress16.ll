; RUN: llc -mtriple=nds32be-unknown-none-elf -verify-machineinstrs < %s | FileCheck %s

; The post-RA NDS32Compress pass rewrites eligible 32-bit instructions into
; 16-bit forms (non-branch only, operand ranges verified).

; CHECK-LABEL: movi:
; CHECK: movi55 $r0, 7
define i32 @movi() { ret i32 7 }

; CHECK-LABEL: addsmall:
; CHECK: addi333 $r0, $r0, 5
define i32 @addsmall(i32 %a) {
  %r = add i32 %a, 5
  ret i32 %r
}

; CHECK-LABEL: ld:
; CHECK: lwi333 $r0, [$r0 + 0]
define i32 @ld(ptr %p) {
  %v = load i32, ptr %p
  ret i32 %v
}

; CHECK-LABEL: st:
; CHECK: swi333 $r1, [$r0 + 0]
define void @st(ptr %p, i32 %v) {
  store i32 %v, ptr %p
  ret void
}

; CHECK-LABEL: copy:
; CHECK: mov55 $r1, $r0
declare void @f(i32, i32)
define void @copy(i32 %a) {
  call void @f(i32 5, i32 %a)
  ret void
}
