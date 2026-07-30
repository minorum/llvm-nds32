# RUN: llvm-mc -triple=nds32be -filetype=obj %s -o %t.o
# RUN: llvm-readobj -r %t.o | FileCheck %s

## Hand-written assembly must be able to name a symbol's address. Codegen could
## always emit these fixups; until now the AsmParser had no syntax for them, so
## a .S file or an inline-asm block could not reference a symbol at all.

    .text
    .globl target
target:
    ret

    .globl user
user:
    sethi $r0, hi20(target)
    ori   $r0, $r0, lo12(target)
    ret

# CHECK:      Relocations [
# CHECK:        R_NDS32_HI20_RELA target
# CHECK-NEXT:   R_NDS32_LO12S0_RELA target
# CHECK:      ]
