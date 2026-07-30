; Hard-float ABI (Andes 2fp+) functions compiled by OUR llc with -mcpu=v3f-hard:
; single-precision floats are passed/returned in $fs registers. Exercised at
; runtime on the sim, called from an Andes-gcc hard-float main.
target datalayout = "E-m:e-p:32:32-i64:32-f64:32-a:0:32-n32-S32"

;; basic f32 arithmetic, args in $fs0/$fs1, result in $fs0
define float @fadd(float %a, float %b) { %r = fadd float %a, %b ret float %r }
define float @fsub(float %a, float %b) { %r = fsub float %a, %b ret float %r }
define float @fmul(float %a, float %b) { %r = fmul float %a, %b ret float %r }
define float @fdiv(float %a, float %b) { %r = fdiv float %a, %b ret float %r }

;; a*b + c (three FP args, one FP result)
define float @fmuladd(float %a, float %b, float %c) {
  %m = fmul float %a, %b
  %r = fadd float %m, %c
  ret float %r
}

;; seven f32 args: $fs0-$fs5 hold six, the seventh spills to the stack.
define float @fsum7(float %a, float %b, float %c, float %d, float %e,
                    float %f, float %g) {
  %1 = fadd float %a, %b
  %2 = fadd float %1, %c
  %3 = fadd float %2, %d
  %4 = fadd float %3, %e
  %5 = fadd float %4, %f
  %6 = fadd float %5, %g
  ret float %6
}

;; mixed int/float args: int pool ($r0,$r1) and FP pool ($fs0,$fs1) are
;; independent. Returns (float)(n+m) + x*y.
define float @fmix(i32 %n, float %x, i32 %m, float %y) {
  %sum = add i32 %n, %m
  %fs  = sitofp i32 %sum to float
  %xy  = fmul float %x, %y
  %r   = fadd float %fs, %xy
  ret float %r
}

;; conversions across the FP/GPR boundary
define i32   @f2i(float %a) { %r = fptosi float %a to i32  ret i32 %r }
define float @i2f(i32 %a)   { %r = sitofp i32 %a to float  ret float %r }

;; OUR code calling OUT to a gcc-provided hard-float function: tests the
;; outgoing-call path passes f32 in $fs0 and reads the f32 result from $fs0.
declare float @gscale(float)
define float @call_gscale(float %x) {
  %s = call float @gscale(float %x)
  %r = fadd float %s, 1.0
  ret float %r
}
