; RUN: llc -mtriple=nds32be-unknown-none-elf -mcpu=v3f -verify-machineinstrs < %s \
; RUN:   | FileCheck %s --check-prefix=HARD
; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s --check-prefix=SOFT

; With the single-precision FPU (-mcpu=v3f), f32 arithmetic uses native FPU
; instructions; the ABI still passes f32 in GPRs (softfp), so values cross the
; GPR/FPR boundary with fmtsr/fmfsr. Without the FPU, f32 falls back to libcalls.

; HARD-LABEL: fadd:
; HARD: fmtsr
; HARD: fadds $fs{{[0-9]+}}, $fs{{[0-9]+}}, $fs{{[0-9]+}}
; HARD: fmfsr
; SOFT-LABEL: fadd:
; SOFT: jal __addsf3
define float @fadd(float %a, float %b) {
  %r = fadd float %a, %b
  ret float %r
}

; HARD-LABEL: fdiv:
; HARD: fdivs $fs{{[0-9]+}}, $fs{{[0-9]+}}, $fs{{[0-9]+}}
define float @fdiv(float %a, float %b) {
  %r = fdiv float %a, %b
  ret float %r
}

; HARD-LABEL: fcmp_lt:
; HARD: fcmplts $fs{{[0-9]+}}, $fs{{[0-9]+}}, $fs{{[0-9]+}}
define i32 @fcmp_lt(float %a, float %b) {
  %c = fcmp olt float %a, %b
  %z = zext i1 %c to i32
  ret i32 %z
}

; HARD-LABEL: i2f:
; HARD: fsi2s $fs{{[0-9]+}}, $fs{{[0-9]+}}
define float @i2f(i32 %a) {
  %r = sitofp i32 %a to float
  ret float %r
}

; HARD-LABEL: f2i:
; HARD: fs2si $fs{{[0-9]+}}, $fs{{[0-9]+}}
define i32 @f2i(float %a) {
  %r = fptosi float %a to i32
  ret i32 %r
}

; HARD-LABEL: fsqrt:
; HARD: fsqrts $fs{{[0-9]+}}, $fs{{[0-9]+}}
define float @fsqrt(float %a) {
  %r = call float @llvm.sqrt.f32(float %a)
  ret float %r
}
declare float @llvm.sqrt.f32(float)
