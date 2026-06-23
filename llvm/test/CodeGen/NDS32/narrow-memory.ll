; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s
; RUN: llc -mtriple=nds32be-unknown-none-elf -filetype=obj < %s -o %t

define i32 @zload8(ptr %p) {
; CHECK-LABEL: zload8:
; CHECK:      lbi $r0, [$r0 + 0]
; CHECK-NEXT: ret
entry:
  %v = load i8, ptr %p, align 1
  %z = zext i8 %v to i32
  ret i32 %z
}

define i32 @sload8(ptr %p) {
; CHECK-LABEL: sload8:
; CHECK:      lbsi $r0, [$r0 + 0]
; CHECK-NEXT: ret
entry:
  %v = load i8, ptr %p, align 1
  %s = sext i8 %v to i32
  ret i32 %s
}

define void @store8(ptr %p, i32 %x) {
; CHECK-LABEL: store8:
; CHECK:      sbi $r1, [$r0 + 0]
; CHECK-NEXT: ret
entry:
  %t = trunc i32 %x to i8
  store i8 %t, ptr %p, align 1
  ret void
}

define i32 @zload16(ptr %p) {
; CHECK-LABEL: zload16:
; CHECK:      lhi $r0, [$r0 + 0]
; CHECK-NEXT: ret
entry:
  %v = load i16, ptr %p, align 2
  %z = zext i16 %v to i32
  ret i32 %z
}

define i32 @sload16(ptr %p) {
; CHECK-LABEL: sload16:
; CHECK:      lhsi $r0, [$r0 + 0]
; CHECK-NEXT: ret
entry:
  %v = load i16, ptr %p, align 2
  %s = sext i16 %v to i32
  ret i32 %s
}

define void @store16(ptr %p, i32 %x) {
; CHECK-LABEL: store16:
; CHECK:      shi $r1, [$r0 + 0]
; CHECK-NEXT: ret
entry:
  %t = trunc i32 %x to i16
  store i16 %t, ptr %p, align 2
  ret void
}

define i32 @zload8_off(ptr %p) {
; CHECK-LABEL: zload8_off:
; CHECK:      lbi $r0, [$r0 + 3]
; CHECK-NEXT: ret
entry:
  %q = getelementptr i8, ptr %p, i32 3
  %v = load i8, ptr %q, align 1
  %z = zext i8 %v to i32
  ret i32 %z
}

define i32 @zload16_off(ptr %p) {
; CHECK-LABEL: zload16_off:
; CHECK:      lhi $r0, [$r0 + 2]
; CHECK-NEXT: ret
entry:
  %q = getelementptr i16, ptr %p, i32 1
  %v = load i16, ptr %q, align 2
  %z = zext i16 %v to i32
  ret i32 %z
}

define void @store16_off(ptr %p, i32 %x) {
; CHECK-LABEL: store16_off:
; CHECK:      shi $r1, [$r0 + 2]
; CHECK-NEXT: ret
entry:
  %q = getelementptr i16, ptr %p, i32 1
  %t = trunc i32 %x to i16
  store i16 %t, ptr %q, align 2
  ret void
}
