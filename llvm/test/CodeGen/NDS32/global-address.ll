; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

@foo = global i32 42, align 4

define i32 @load_global() {
; CHECK-LABEL: load_global:
; CHECK:      sethi $r0, hi20(foo)
; CHECK-NEXT: addi $r0, $r0, lo12(foo)
; CHECK-NEXT: lwi333 $r0, [$r0 + 0]
; CHECK-NEXT: ret
entry:
  %val = load i32, ptr @foo, align 4
  ret i32 %val
}

define void @store_global(i32 %val) {
; CHECK-LABEL: store_global:
; CHECK:      sethi $r1, hi20(foo)
; CHECK-NEXT: addi $r1, $r1, lo12(foo)
; CHECK-NEXT: swi333 $r0, [$r1 + 0]
; CHECK-NEXT: ret
entry:
  store i32 %val, ptr @foo, align 4
  ret void
}

define ptr @get_global_ptr() {
; CHECK-LABEL: get_global_ptr:
; CHECK:      sethi $r0, hi20(foo)
; CHECK-NEXT: addi $r0, $r0, lo12(foo)
; CHECK-NEXT: ret
entry:
  ret ptr @foo
}
