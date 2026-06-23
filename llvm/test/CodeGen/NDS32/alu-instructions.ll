; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

define i32 @test_sub(i32 %a, i32 %b) {
; CHECK-LABEL: test_sub:
; CHECK: sub	$r0, $r0, $r1
; CHECK: ret
  %res = sub i32 %a, %b
  ret i32 %res
}

define i32 @test_mul(i32 %a, i32 %b) {
; CHECK-LABEL: test_mul:
; CHECK: mul	$r0, $r0, $r1
; CHECK: ret
  %res = mul i32 %a, %b
  ret i32 %res
}

define i32 @test_and(i32 %a, i32 %b) {
; CHECK-LABEL: test_and:
; CHECK: and	$r0, $r0, $r1
; CHECK: ret
  %res = and i32 %a, %b
  ret i32 %res
}

define i32 @test_or(i32 %a, i32 %b) {
; CHECK-LABEL: test_or:
; CHECK: or	$r0, $r0, $r1
; CHECK: ret
  %res = or i32 %a, %b
  ret i32 %res
}

define i32 @test_xor(i32 %a, i32 %b) {
; CHECK-LABEL: test_xor:
; CHECK: xor	$r0, $r0, $r1
; CHECK: ret
  %res = xor i32 %a, %b
  ret i32 %res
}

define i32 @test_sll(i32 %a, i32 %b) {
; CHECK-LABEL: test_sll:
; CHECK: sll	$r0, $r0, $r1
; CHECK: ret
  %res = shl i32 %a, %b
  ret i32 %res
}

define i32 @test_srl(i32 %a, i32 %b) {
; CHECK-LABEL: test_srl:
; CHECK: srl	$r0, $r0, $r1
; CHECK: ret
  %res = lshr i32 %a, %b
  ret i32 %res
}

define i32 @test_sra(i32 %a, i32 %b) {
; CHECK-LABEL: test_sra:
; CHECK: sra	$r0, $r0, $r1
; CHECK: ret
  %res = ashr i32 %a, %b
  ret i32 %res
}

define i32 @test_andi(i32 %a) {
; CHECK-LABEL: test_andi:
; CHECK: andi	$r0, $r0, 100
; CHECK: ret
  %res = and i32 %a, 100
  ret i32 %res
}

define i32 @test_ori(i32 %a) {
; CHECK-LABEL: test_ori:
; CHECK: ori	$r0, $r0, 100
; CHECK: ret
  %res = or i32 %a, 100
  ret i32 %res
}

define i32 @test_xori(i32 %a) {
; CHECK-LABEL: test_xori:
; CHECK: xori	$r0, $r0, 100
; CHECK: ret
  %res = xor i32 %a, 100
  ret i32 %res
}

define i32 @test_slli(i32 %a) {
; CHECK-LABEL: test_slli:
; CHECK: slli	$r0, $r0, 5
; CHECK: ret
  %res = shl i32 %a, 5
  ret i32 %res
}

define i32 @test_srli(i32 %a) {
; CHECK-LABEL: test_srli:
; CHECK: srli	$r0, $r0, 5
; CHECK: ret
  %res = lshr i32 %a, 5
  ret i32 %res
}

define i32 @test_srai(i32 %a) {
; CHECK-LABEL: test_srai:
; CHECK: srai	$r0, $r0, 5
; CHECK: ret
  %res = ashr i32 %a, 5
  ret i32 %res
}

define i32 @test_slti(i32 %a) {
; CHECK-LABEL: test_slti:
; CHECK: slti	$r0, $r0, 100
; CHECK: ret
  %c = icmp ult i32 %a, 100
  %res = zext i1 %c to i32
  ret i32 %res
}

define i32 @test_sltsi(i32 %a) {
; CHECK-LABEL: test_sltsi:
; CHECK: sltsi	$r0, $r0, 100
; CHECK: ret
  %c = icmp slt i32 %a, 100
  %res = zext i1 %c to i32
  ret i32 %res
}
