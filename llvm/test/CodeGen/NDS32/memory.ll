; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

define i32 @load_arg_ptr(ptr %p) {
; CHECK-LABEL: load_arg_ptr:
; CHECK: lwi333	$r0, [$r0 + 0]
; CHECK: ret
entry:
  %v = load i32, ptr %p, align 4
  ret i32 %v
}

define void @store_arg_ptr(ptr %p, i32 %x) {
; CHECK-LABEL: store_arg_ptr:
; CHECK: swi333	$r1, [$r0 + 0]
; CHECK: ret
entry:
  store i32 %x, ptr %p, align 4
  ret void
}

define i32 @stack_slot_volatile(i32 %x) {
; CHECK-LABEL: stack_slot_volatile:
; CHECK: addi	$r31, $r31, -4
; CHECK: swi	$r0, [$r31 + 0]
; CHECK: lwi	$r0, [$r31 + 0]
; CHECK: addi	$r31, $r31, 4
; CHECK: ret
entry:
  %slot = alloca i32, align 4
  store volatile i32 %x, ptr %slot, align 4
  %v = load volatile i32, ptr %slot, align 4
  ret i32 %v
}
