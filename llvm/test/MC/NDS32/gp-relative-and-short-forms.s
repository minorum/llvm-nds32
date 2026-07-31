// RUN: llvm-mc -triple nds32be -mcpu=v3 -show-encoding %s | FileCheck %s
// RUN: llvm-mc -triple nds32be -mcpu=v3 -filetype=obj %s \
// RUN:   | llvm-objdump -d --triple=nds32be - | FileCheck --check-prefix=DIS %s

// Instruction forms that appear throughout the MT6785 connectivity firmware but
// had no encoding here, plus the print/parse asymmetries found alongside them.
// Every encoding below is taken from vendor machine code and cross-checked
// against Ghidra over 12570 instructions, not derived by hand -- an earlier
// hand reading of this ISA got `ori`, `andi`/`slti` and LMW/SMW all wrong.

// The displacement is 19 bits and unscaled: op6 already fixes the access width.
// $gp sits above its data in this firmware, so every real offset is negative --
// which is exactly the case a too-narrow field silently corrupts.
// CHECK: addi.gp $r1, -207684 ! encoding: [0x3e,0x1c,0xd4,0xbc]
addi.gp $r1, -207684
// CHECK: lbi.gp $r0, [+ -202992] ! encoding: [0x2e,0x04,0xe7,0x10]
lbi.gp $r0, [+ -202992]
// CHECK: sbi.gp $r6, [+ -190181] ! encoding: [0x3e,0x65,0x19,0x1b]
sbi.gp $r6, [+ -190181]
// lbsi.gp, slts45 and a non-zero swi37.sp offset do not occur in the firmware,
// so unlike the rest of this file they rest on the shared format rather than on
// observed bytes.
// CHECK: lbsi.gp $r0, [+ -202992] ! encoding: [0x2e,0x0c,0xe7,0x10]
lbsi.gp $r0, [+ -202992]

// Halfword gp-relative: 18-bit field holding a halfword count, so the printed
// byte displacement must be even.
// CHECK: lhi.gp $r2, [+ -198022] ! encoding: [0x3c,0x22,0x7d,0x3d]
lhi.gp $r2, [+ -198022]
// CHECK: shi.gp $r1, [+ -167980] ! encoding: [0x3c,0x1a,0xb7,0xea]
shi.gp $r1, [+ -167980]

// The word forms already existed, but `[+ off]` -- the syntax their own printer
// emits -- did not parse, so they could not be written by hand at all.
// CHECK: lwi.gp $r0, [+ -262144] ! encoding: [0x3c,0x0d,0x00,0x00]
lwi.gp $r0, [+ -262144]
// CHECK: swi.gp $r0, [+ -262144] ! encoding: [0x3c,0x0f,0x00,0x00]
swi.gp $r0, [+ -262144]

// slt/slti are the unsigned pair, slts/sltsi the signed one. The result is
// implicit in $ta, so only the compared values are named.
// CHECK: slt45 $r6, $r2 ! encoding: [0xe2,0xc2]
slt45 $r6, $r2
// CHECK: slts45 $r6, $r2 ! encoding: [0xe0,0xc2]
slts45 $r6, $r2
// CHECK: slti45 $r2, 6 ! encoding: [0xe6,0x46]
slti45 $r2, 6
// CHECK: sltsi45 $r0, 6 ! encoding: [0xe4,0x06]
sltsi45 $r0, 6

// ...and these test $ta, which is what buys them a full 8-bit displacement.
// The field is the displacement halved; it was previously encoded unscaled, so
// the assembler and disassembler disagreed by a factor of two.
// CHECK: beqzs8 10 ! encoding: [0xe8,0x05]
beqzs8 10
// CHECK: bnezs8 -10 ! encoding: [0xe9,0xfb]
bnezs8 -10

// $fp-relative word load/store, and the pre-existing $sp forms whose offset was
// likewise encoded unscaled.
// CHECK: lwi37 $r1, [+ 4] ! encoding: [0xb9,0x01]
lwi37 $r1, [+ 4]
// CHECK: swi37 $r0, [+ 4] ! encoding: [0xb8,0x81]
swi37 $r0, [+ 4]
// CHECK: lwi37.sp $r1, [+ 4] ! encoding: [0xf1,0x01]
lwi37.sp $r1, [+ 4]
// CHECK: swi37.sp $r1, [+ 36] ! encoding: [0xf1,0x89]
swi37.sp $r1, [+ 36]

// Every line above must survive assemble -> disassemble unchanged. That is the
// property the encodings are actually for: the carried-over-machine-code
// pipeline in the firmware tree cannot round-trip through mnemonics, and this
// is the test that says why it now could.
// DIS: addi.gp	$r1, -0x32b44
// DIS: lbi.gp	$r0, [+ -0x318f0]
// DIS: sbi.gp	$r6, [+ -0x2e6e5]
// DIS: lbsi.gp	$r0, [+ -0x318f0]
// DIS: lhi.gp	$r2, [+ -0x30586]
// DIS: shi.gp	$r1, [+ -0x2902c]
// DIS: lwi.gp	$r0, [+ -0x40000]
// DIS: swi.gp	$r0, [+ -0x40000]
// DIS: slt45	$r6, $r2
// DIS: slts45	$r6, $r2
// Not annotated with a target: these are comparisons, not branches. They sat
// inside a `let isBranch = 1` scope at first, and objdump duly reported the
// immediate 6 as an address.
// DIS: slti45	$r2, 0x6{{$}}
// DIS: sltsi45	$r0, 0x6{{$}}
// DIS: beqzs8	0xa <.text+0x32>
// DIS: bnezs8	-0xa <.text+0x20>
// DIS: lwi37	$r1, [+ 0x4]{{$}}
// DIS: swi37	$r0, [+ 0x4]{{$}}
// DIS: lwi37.sp	$r1, [+ 0x4]
// DIS: swi37.sp	$r1, [+ 0x24]
