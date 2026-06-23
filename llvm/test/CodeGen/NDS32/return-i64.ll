; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s --check-prefixes=CHECK,CHECK-BE
; RUN: llc -mtriple=nds32le-unknown-none-elf < %s | FileCheck %s --check-prefixes=CHECK,CHECK-LE

define i64 @const_i64() {
; CHECK-LABEL: const_i64:
; CHECK-BE: movi	$r0, 2874
; CHECK-BE-NEXT: movi	$r1, 1942892530
; CHECK-LE: movi	$r0, 1942892530
; CHECK-LE-NEXT: movi	$r1, 2874
; CHECK-NEXT: ret
  ret i64 12345678901234
}

define i64 @test_i64_add(i64 %a, i64 %b) {
; CHECK-LABEL: test_i64_add:
; CHECK-BE: add	$r0, $r0, $r2
; CHECK-BE-NEXT: add	$r2, $r1, $r3
; CHECK-BE-NEXT: slt	$r1, $r2, $r1
; CHECK-BE-NEXT: add	$r0, $r0, $r1
; CHECK-BE-NEXT: addi	$r1, $r2, 0
; CHECK-LE: add	$r1, $r1, $r3
; CHECK-LE-NEXT: add	$r2, $r0, $r2
; CHECK-LE-NEXT: slt	$r0, $r2, $r0
; CHECK-LE-NEXT: add	$r1, $r1, $r0
; CHECK-LE-NEXT: addi	$r0, $r2, 0
; CHECK-NEXT: ret
  %c = add i64 %a, %b
  ret i64 %c
}

define i64 @test_i64_stack(i64 %a, i64 %b, i64 %c, i64 %d) {
; CHECK-LABEL: test_i64_stack:
; CHECK: lwi	{{\$r[0-9]+}}, [{{\$r31 \+ [0-9]+}}]
; CHECK: lwi	{{\$r[0-9]+}}, [{{\$r31 \+ [0-9]+}}]
; CHECK: ret
  %1 = add i64 %a, %b
  %2 = add i64 %1, %c
  %3 = add i64 %2, %d
  ret i64 %3
}
