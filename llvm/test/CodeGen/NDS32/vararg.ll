; RUN: llc -mtriple=nds32be-unknown-none-elf -verify-machineinstrs < %s | FileCheck %s

; A variadic callee spills the argument registers not used by named arguments
; into a save area, and va_start hands out its address. Here %n takes $r0, so
; $r1-$r5 are spilled and va_list points at $r1's slot.

; CHECK-LABEL: sum2:
; CHECK: swi $r5, [$r31 + 20]
; CHECK: swi $r1, [$r31 + 4]
define i32 @sum2(i32 %n, ...) {
entry:
  %ap = alloca ptr
  call void @llvm.va_start(ptr %ap)
  %p = load ptr, ptr %ap
  %v0 = load i32, ptr %p
  %p1 = getelementptr i32, ptr %p, i32 1
  %v1 = load i32, ptr %p1
  call void @llvm.va_end(ptr %ap)
  %s = add i32 %v0, %v1
  ret i32 %s
}
declare void @llvm.va_start(ptr)
declare void @llvm.va_end(ptr)

; A call to a variadic function passes extra args in registers/stack normally.
; CHECK-LABEL: callit:
; CHECK: jal printf
@.str = constant [4 x i8] c"%d\0A\00"
define void @callit(i32 %x) {
  %r = call i32 (ptr, ...) @printf(ptr @.str, i32 %x, i32 42)
  ret void
}
declare i32 @printf(ptr, ...)
