; RUN: llc -mtriple=nds32be-unknown-none-elf -mcpu=v3f-hard < %s \
; RUN:   | FileCheck %s --check-prefix=HARD
; RUN: llc -mtriple=nds32be-unknown-none-elf -mcpu=v3f < %s \
; RUN:   | FileCheck %s --check-prefix=SOFT
;
; Hard-float ABI (2fp+): f32 args/returns travel in $fs registers, so a leaf
; fadds needs no GPR<->FPR boxing. The softfp v3f ABI passes f32 in GPRs, so the
; same function must fmtsr the incoming GPRs in and fmfsr the result out.

define float @fadd(float %a, float %b) {
; HARD-LABEL: fadd:
; HARD:       fadds $fs0, $fs0, $fs1
; HARD-NEXT:  ret
; HARD-NOT:   fmtsr
; HARD-NOT:   fmfsr
;
; SOFT-LABEL: fadd:
; SOFT:       fmtsr
; SOFT:       fmfsr
  %r = fadd float %a, %b
  ret float %r
}

; Independent int/float register pools: ints in $r0/$r1, floats in $fs0/$fs1.
define float @fmix(i32 %n, float %x, i32 %m, float %y) {
; HARD-LABEL: fmix:
; HARD-DAG:   add45 $r0, $r1
; HARD-DAG:   fmuls $fs0, $fs0, $fs1
  %sum = add i32 %n, %m
  %fs  = sitofp i32 %sum to float
  %xy  = fmul float %x, %y
  %r   = fadd float %fs, %xy
  ret float %r
}
