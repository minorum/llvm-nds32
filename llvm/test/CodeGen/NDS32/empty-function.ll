; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

define void @entry() {
; CHECK-LABEL: entry:
; CHECK: ret
; CHECK: .size entry,
  ret void
}
