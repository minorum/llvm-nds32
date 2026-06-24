; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

; Inline-assembly constraint support: "r" register, "I"/"J"/"K" immediates
; (signed 15-bit / signed 20-bit / unsigned 15-bit), and "m" memory operands
; formatted as the NDS32 "[$base + off]" addressing syntax.

; CHECK-LABEL: asm_r:
; CHECK: mov $r{{[0-9]+}}, $r{{[0-9]+}}
define i32 @asm_r(i32 %a) {
  %r = call i32 asm "mov $0, $1", "=r,r"(i32 %a)
  ret i32 %r
}

; CHECK-LABEL: asm_I:
; CHECK: addi $r{{[0-9]+}}, $r{{[0-9]+}}, 5
define i32 @asm_I(i32 %a) {
  %r = call i32 asm "addi $0, $1, $2", "=r,r,I"(i32 %a, i32 5)
  ret i32 %r
}

; CHECK-LABEL: asm_J:
; CHECK: movi $r{{[0-9]+}}, 524287
define i32 @asm_J(i32 %a) {
  %r = call i32 asm "movi $0, $2", "=r,r,J"(i32 %a, i32 524287)
  ret i32 %r
}

; CHECK-LABEL: asm_K:
; CHECK: ori $r{{[0-9]+}}, $r{{[0-9]+}}, 4095
define i32 @asm_K(i32 %a) {
  %r = call i32 asm "ori $0, $1, $2", "=r,r,K"(i32 %a, i32 4095)
  ret i32 %r
}

; CHECK-LABEL: asm_mem:
; CHECK: lwi $r{{[0-9]+}}, [$r{{[0-9]+}} + 0]
define i32 @asm_mem(ptr %p) {
  %r = call i32 asm "lwi $0, $1", "=r,*m"(ptr elementtype(i32) %p)
  ret i32 %r
}
