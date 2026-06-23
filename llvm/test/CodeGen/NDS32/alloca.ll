; RUN: llc -mtriple=nds32be-unknown-none-elf -verify-machineinstrs < %s | FileCheck %s

; Dynamic alloca needs a frame pointer ($r28): fixed locals and the callee-saved
; area are reached from $fp, which is stable while $sp moves for the alloca.

; CHECK-LABEL: dyn:
; Prologue: allocate the fixed frame, save the OLD $fp ($sp-relative) before
; establishing the new frame pointer.
; CHECK: addi $r31, $r31, -{{[0-9]+}}
; CHECK: swi $r28, [$r31 + {{[0-9]+}}]
; CHECK: addi $r28, $r31, 0
; The alloca subtracts the (aligned) size from $sp.
; CHECK: sub $r{{[0-9]+}}, $r31, $r{{[0-9]+}}
; Epilogue: restore $sp from $fp, reload the old $fp, then deallocate.
; CHECK: addi $r31, $r28, 0
; CHECK: lwi $r28, [$r31 + {{[0-9]+}}]
; CHECK: ret
define i32 @dyn(i32 %n) {
  %p = alloca i32, i32 %n
  store i32 7, ptr %p
  %r = load i32, ptr %p
  ret i32 %r
}

; __builtin_frame_address forces a frame pointer too.
; CHECK-LABEL: fa:
; CHECK: addi $r28, $r31, 0
define ptr @fa() {
  %r = call ptr @llvm.frameaddress.p0(i32 0)
  ret ptr %r
}
declare ptr @llvm.frameaddress.p0(i32)
