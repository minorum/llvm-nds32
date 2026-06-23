; RUN: llc -mtriple=nds32be-unknown-none-elf -verify-machineinstrs < %s | FileCheck %s

; Pointer-walking loops fuse the pointer increment into the access with the
; post-increment addressing forms lwi.bi / swi.bi.

; CHECK-LABEL: sum:
; CHECK: lwi.bi $r{{[0-9]+}}, [$r{{[0-9]+}}], 4
define i32 @sum(ptr %a, i32 %n) {
entry:
  br label %loop
loop:
  %p = phi ptr [ %a, %entry ], [ %p.next, %loop ]
  %i = phi i32 [ 0, %entry ], [ %i.next, %loop ]
  %acc = phi i32 [ 0, %entry ], [ %acc.next, %loop ]
  %v = load i32, ptr %p
  %p.next = getelementptr i32, ptr %p, i32 1
  %acc.next = add i32 %acc, %v
  %i.next = add i32 %i, 1
  %done = icmp eq i32 %i.next, %n
  br i1 %done, label %exit, label %loop
exit:
  ret i32 %acc.next
}

; CHECK-LABEL: zero:
; CHECK: swi.bi $r{{[0-9]+}}, [$r{{[0-9]+}}], 4
define void @zero(ptr %a, i32 %n) {
entry:
  br label %loop
loop:
  %p = phi ptr [ %a, %entry ], [ %p.next, %loop ]
  %i = phi i32 [ 0, %entry ], [ %i.next, %loop ]
  store i32 0, ptr %p
  %p.next = getelementptr i32, ptr %p, i32 1
  %i.next = add i32 %i, 1
  %done = icmp eq i32 %i.next, %n
  br i1 %done, label %exit, label %loop
exit:
  ret void
}
