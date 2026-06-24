; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s --check-prefixes=CHECK,CHECK-BE
; RUN: llc -mtriple=nds32le-unknown-none-elf < %s | FileCheck %s --check-prefixes=CHECK,CHECK-LE

define i64 @const_i64() {
; CHECK-LABEL: const_i64:
; CHECK-BE: sethi	$r0, 474338
; CHECK-BE-NEXT: ori	$r1, $r0, 4082
; CHECK-BE-NEXT: movi	$r0, 2874
; CHECK-LE: sethi	$r0, 474338
; CHECK-LE-NEXT: ori	$r0, $r0, 4082
; CHECK-LE-NEXT: movi	$r1, 2874
; CHECK-NEXT: ret
  ret i64 12345678901234
}

define i64 @test_i64_add(i64 %a, i64 %b) {
; CHECK-LABEL: test_i64_add:
; CHECK-BE: add45	$r0, $r2
; CHECK-BE-NEXT: add	$r2, $r1, $r3
; CHECK-BE-NEXT: slt	$r1, $r2, $r1
; CHECK-BE-NEXT: add45	$r0, $r1
; CHECK-BE-NEXT: mov55	$r1, $r2
; CHECK-LE: add45	$r1, $r3
; CHECK-LE-NEXT: add45	$r2, $r0
; CHECK-LE-NEXT: slt	$r0, $r2, $r0
; CHECK-LE-NEXT: add45	$r1, $r0
; CHECK-LE-NEXT: mov55	$r0, $r2
; CHECK-NEXT: ret
  %c = add i64 %a, %b
  ret i64 %c
}

define i64 @test_i64_stack(i64 %a, i64 %b, i64 %c, i64 %d) {
; CHECK-LABEL: test_i64_stack:
; CHECK: lwi	{{\$r[0-9]+}}, [{{\$sp \+ [0-9]+}}]
; CHECK: lwi	{{\$r[0-9]+}}, [{{\$sp \+ [0-9]+}}]
; CHECK: ret
  %1 = add i64 %a, %b
  %2 = add i64 %1, %c
  %3 = add i64 %2, %d
  ret i64 %3
}
