; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s --check-prefix=ASM
; RUN: llc -mtriple=nds32be-unknown-none-elf -filetype=obj < %s -o %t.o
; RUN: llvm-objdump -d --triple=nds32be-unknown-none-elf %t.o \
; RUN:   | FileCheck %s --check-prefix=OBJ
;
; 16-bit short branches: an in-range conditional loop edge compresses to bnez38
; and an unconditional edge to j8 (both 2-byte). A branch whose target is beyond
; the +/-256B short range is grown back to the 32-bit form by the assembler's
; relaxation pass.

; In-range backward conditional loop edge -> 2-byte bnez38.
; ASM-LABEL: loopfn:
; ASM: bnez38 $r{{[0-7]}}, .LBB0_1
; OBJ-LABEL: <loopfn>:
; OBJ: bnez38 $r{{[0-7]}},
define i32 @loopfn(i32 %n) {
entry: br label %loop
loop:
  %i = phi i32 [0,%entry],[%ni,%loop]
  %a = phi i32 [0,%entry],[%na,%loop]
  %na = add i32 %a, %i
  %ni = add i32 %i, 1
  %c = icmp slt i32 %ni, %n
  br i1 %c, label %loop, label %done
done: ret i32 %na
}

; Unconditional edge -> 2-byte j8.
; ASM-LABEL: spin:
; ASM: j8 .LBB1_1
; OBJ-LABEL: <spin>:
; OBJ: j8
define void @spin() {
  br label %l
l:
  br label %l
}

; Target beyond +/-256B (a 400-byte .fill between the branch and its target)
; must relax to the 32-bit beqz -- the 16-bit beqz38 cannot reach it.
; OBJ-LABEL: <farfn>:
; OBJ: beqz $r0,
; OBJ-NOT: beqz38
define i32 @farfn(i32 %a) {
entry:
  %c = icmp eq i32 %a, 0
  br i1 %c, label %done, label %big
big:
  call void asm sideeffect ".fill 400, 1, 0", ""()
  br label %done
done:
  ret i32 %a
}
