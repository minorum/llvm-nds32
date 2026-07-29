; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

; Efficiency patterns: branchless select (cmovn/cmovz), native clz, bswap via
; wsbh+rotri, multiply-accumulate (maddr32/msubr32), and bit-clear-immediate.

; A select lowers to a branchless cmovn/cmovz pair (no compare-and-branch).
; CHECK-LABEL: sel:
; CHECK-NOT: beqz
; CHECK-NOT: bnez
; CHECK: cmovn
; CHECK: cmovz
define i32 @sel(i32 %c, i32 %t, i32 %f) {
  %b = icmp ne i32 %c, 0
  %r = select i1 %b, i32 %t, i32 %f
  ret i32 %r
}

; CTLZ (zero defined) is a single clz with no zero-check branch, because clz
; already returns 32 for a zero input.
; CHECK-LABEL: clz0:
; CHECK-NOT: beqz
; CHECK: clz $r{{[0-9]+}}, $r{{[0-9]+}}
define i32 @clz0(i32 %x) {
  %r = call i32 @llvm.ctlz.i32(i32 %x, i1 false)
  ret i32 %r
}
declare i32 @llvm.ctlz.i32(i32, i1)

; CHECK-LABEL: bswap:
; CHECK: wsbh $r{{[0-9]+}}, $r{{[0-9]+}}
; CHECK: rotri $r{{[0-9]+}}, $r{{[0-9]+}}, 16
define i32 @bswap(i32 %x) {
  %r = call i32 @llvm.bswap.i32(i32 %x)
  ret i32 %r
}
declare i32 @llvm.bswap.i32(i32)

; CHECK-LABEL: mac:
; CHECK: maddr32 $r{{[0-9]+}}, $r{{[0-9]+}}, $r{{[0-9]+}}
define i32 @mac(i32 %a, i32 %b, i32 %c) {
  %m = mul i32 %b, %c
  %r = add i32 %a, %m
  ret i32 %r
}

; CHECK-LABEL: msub:
; CHECK: msubr32 $r{{[0-9]+}}, $r{{[0-9]+}}, $r{{[0-9]+}}
define i32 @msub(i32 %a, i32 %b, i32 %c) {
  %m = mul i32 %b, %c
  %r = sub i32 %a, %m
  ret i32 %r
}

; AND with a constant whose complement fits 15 bits clears low bits via bitci --
; but ONLY from V3 up. This file runs without -mcpu, i.e. "generic" == V2, where
; bitci is illegal and traps, so the expected lowering here is movi+and. Both
; directions are asserted in bitci-v3-only.ll.
; CHECK-LABEL: bitclear:
; CHECK: movi $r{{[0-9]+}}, -256
; CHECK: and $r{{[0-9]+}}, $r{{[0-9]+}}, $r{{[0-9]+}}
; CHECK-NOT: bitci
define i32 @bitclear(i32 %x) {
  %r = and i32 %x, 4294967040 ; ~0xff
  ret i32 %r
}
