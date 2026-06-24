; RUN: llc -mtriple=nds32be-unknown-none-elf -filetype=obj < %s -o %t.o
; RUN: llvm-objdump -s -j .text %t.o | FileCheck %s

; Regression test for the branch fixup masks. beqz/bnez share a 16-bit
; displacement field; bit 16 is the eq/ne sub-opcode (beqz=0x4e02xxxx,
; bnez=0x4e03xxxx). beq/bne share a 14-bit field; bit 14 is the eq/ne
; sub-opcode (beq=0x4c008xxx, bne=0x4c00cxxx). When a branch is resolved
; internally (a local forward branch, no relocation), applyFixup must not let
; the displacement clobber that sub-opcode bit, or bnez silently becomes beqz
; and bne silently becomes beq. The "15"/"17" in the fixup names are the
; PC-relative ranges (disp << 1), NOT the field widths.

; A local forward "bne" with a small positive displacement (sub-opcode bit
; clear in the displacement). With the buggy 15-bit mask this encoded as beq
; (0x4c008004); the field is 14 bits, so it must stay bne (0x4c00c004).
define i32 @bne_local(i32 %a, i32 %b) {
; CHECK: Contents of section .text:
; CHECK: 4c00c004
  %c = icmp ne i32 %a, %b
  br i1 %c, label %ne, label %eq, !prof !0
ne:
  ret i32 42
eq:
  ret i32 %a
}

; A nonzero-test "icmp ne i32 %a, 0" lowers to a local forward "bnez" with a
; small positive displacement (sub-opcode bit clear in the displacement). With
; the buggy 17-bit mask the displacement cleared bit 16 and this encoded as
; beqz (0x4e02....); it must stay bnez (0x4e03....).
define i32 @bnez_local(i32 %a) {
; CHECK: 4e03
  %c = icmp ne i32 %a, 0
  br i1 %c, label %ne, label %eq, !prof !0
ne:
  ret i32 42
eq:
  ret i32 7
}

!0 = !{!"branch_weights", i32 1, i32 2000}
