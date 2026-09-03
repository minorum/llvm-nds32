; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

declare void @llvm.nds32.dsb()
declare void @llvm.nds32.isb()
declare void @llvm.nds32.setgie.d()
declare void @llvm.nds32.setgie.e()
declare void @llvm.nds32.standby(i32 immarg)
declare void @llvm.nds32.break16(i32 immarg)

define void @barriers() {
; CHECK-LABEL: barriers:
; CHECK: dsb
; CHECK-NEXT: isb
  call void @llvm.nds32.dsb()
  call void @llvm.nds32.isb()
  ret void
}

define void @interrupt_state() {
; CHECK-LABEL: interrupt_state:
; CHECK: setgie.d
; CHECK-NEXT: setgie.e
  call void @llvm.nds32.setgie.d()
  call void @llvm.nds32.setgie.e()
  ret void
}

define void @wait_done() {
; CHECK-LABEL: wait_done:
; CHECK: standby 2
  call void @llvm.nds32.standby(i32 2)
  ret void
}

define void @debug_break() {
; CHECK-LABEL: debug_break:
; CHECK: break16 0
  call void @llvm.nds32.break16(i32 0)
  ret void
}
