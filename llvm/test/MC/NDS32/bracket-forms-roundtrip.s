// RUN: llvm-mc -triple nds32be -mcpu=v3 -show-encoding %s | FileCheck %s

// The assembler must be able to read back everything its own disassembler
// prints. It could not, and the gaps were structural rather than incidental:
// the parser decided how to read a bracket from the mnemonic, and its test was
// `Name.ends_with(".bi")`. That covered two instructions and missed four whole
// families -- which is why the firmware's own prologue instruction could not be
// assembled while its rarely-used sibling could.
//
// With these fixed, all 12570 instructions of carried-over vendor machine code
// in the firmware tree survive disassemble -> reassemble byte-identically.

// Load/store multiple. Only the two non-updating forms used to parse; the four
// that write the base back did not, and `smw.adm`/`lmw.bim` are the commonest
// prologue/epilogue pair in the firmware (123 and 125 uses).
// CHECK: smw.bi $r6, [$sp], $r10, 10   ! encoding: [0x3a,0x6f,0xaa,0xa0]
smw.bi $r6, [$sp], $r10, 10
// CHECK: smw.bim $r6, [$sp], $r10, 10  ! encoding: [0x3a,0x6f,0xaa,0xa4]
smw.bim $r6, [$sp], $r10, 10
// CHECK: smw.adm $r6, [$sp], $r10, 10  ! encoding: [0x3a,0x6f,0xaa,0xbc]
smw.adm $r6, [$sp], $r10, 10
// CHECK: lmw.bi $r6, [$sp], $r10, 10   ! encoding: [0x3a,0x6f,0xaa,0x80]
lmw.bi $r6, [$sp], $r10, 10
// CHECK: lmw.bim $r6, [$sp], $r10, 10  ! encoding: [0x3a,0x6f,0xaa,0x84]
lmw.bim $r6, [$sp], $r10, 10
// CHECK: lmw.aim $r6, [$sp], $r10, 10  ! encoding: [0x3a,0x6f,0xaa,0x94]
lmw.aim $r6, [$sp], $r10, 10

// 16-bit "450": a bare base register in brackets.
// CHECK: lwi450 $r4, [$r3]             ! encoding: [0xb4,0x83]
lwi450 $r4, [$r3]
// CHECK: swi450 $r4, [$r5]             ! encoding: [0xb6,0x85]
swi450 $r4, [$r5]

// 16-bit "333": base and displacement as two operands, not one memory operand.
// CHECK: lwi333 $r5, [$r3 + 4]         ! encoding: [0xa1,0x59]
lwi333 $r5, [$r3 + 4]
// CHECK: lbi333 $r4, [$r3 + 0]         ! encoding: [0xa7,0x18]
lbi333 $r4, [$r3 + 0]
// CHECK: sbi333 $r7, [$r0 + 1]         ! encoding: [0xaf,0xc1]
sbi333 $r7, [$r0 + 1]
// The halfword forms scale by two. `off3half` had a decoder but no encoder, so
// the assembler took the printed byte offset as a halfword count and disagreed
// with its own disassembler by a factor of two.
// CHECK: lhi333 $r7, [$r0 + 2]         ! encoding: [0xa5,0xc1]
lhi333 $r7, [$r0 + 2]
// CHECK: shi333 $r7, [$r0 + 2]         ! encoding: [0xad,0xc1]
shi333 $r7, [$r0 + 2]
// ...and the post-increment 333 puts its step AFTER the bracket, so it is a
// bare-register form despite the name.
// CHECK: lwi333.bi $r0, [$r1], 4       ! encoding: [0xa2,0x09]
lwi333.bi $r0, [$r1], 4

// Negative displacements arrive as a Minus token rather than inside the
// expression. These used to fail to parse, and a first attempt that wrapped
// them in an MCUnaryExpr encoded 0 for a word offset and crashed the assembler
// outright on a byte one -- so the constant is folded at parse time.
// CHECK: lbi $r1, [$r7 - 18]           ! encoding: [0x00,0x13,0xff,0xee]
lbi $r1, [$r7 - 18]
// CHECK: swi $r1, [$r0 - 4]            ! encoding: [0x14,0x10,0x7f,0xff]
swi $r1, [$r0 - 4]
// CHECK: lwi $r0, [$r7 - 16]           ! encoding: [0x04,0x03,0xff,0xfc]
lwi $r0, [$r7 - 16]
