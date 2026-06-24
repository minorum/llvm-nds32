; RUN: llc -mtriple=nds32be-unknown-none-elf -verify-machineinstrs < %s | FileCheck %s

; Dynamic alloca needs a frame pointer ($fp): fixed locals and the callee-saved
; area are reached from $fp, which is stable while $sp moves for the alloca.

; CHECK-LABEL: dyn:
; Prologue: allocate the fixed frame, save the OLD $fp ($sp-relative) before
; establishing the new frame pointer.
; CHECK: addi $sp, $sp, -{{[0-9]+}}
; CHECK: swi $fp, [$sp + {{[0-9]+}}]
; CHECK: mov55 $fp, $sp
; The alloca subtracts the (aligned) size from $sp.
; CHECK: sub $r{{[0-9]+}}, $sp, $r{{[0-9]+}}
; Epilogue: restore $sp from $fp, reload the old $fp, then deallocate.
; CHECK: mov55 $sp, $fp
; CHECK: lwi $fp, [$sp + {{[0-9]+}}]
; CHECK: ret
define i32 @dyn(i32 %n) {
  %p = alloca i32, i32 %n
  store i32 7, ptr %p
  %r = load i32, ptr %p
  ret i32 %r
}

; __builtin_frame_address forces a frame pointer too.
; CHECK-LABEL: fa:
; CHECK: mov55 $fp, $sp
define ptr @fa() {
  %r = call ptr @llvm.frameaddress.p0(i32 0)
  ret ptr %r
}
declare ptr @llvm.frameaddress.p0(i32)
