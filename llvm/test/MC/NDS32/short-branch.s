# RUN: llvm-mc -triple=nds32be-unknown-none-elf -filetype=obj %s -o %t.o
# RUN: llvm-objdump -d --triple=nds32be-unknown-none-elf %t.o | FileCheck %s
#
# The assembler's relaxation pass keeps an in-range 16-bit short branch short and
# grows an out-of-range one to its 32-bit form. A self-referential beqz38/j8
# (displacement 0) is trivially in range; the second beqz38 must reach across a
# 400-byte gap, which exceeds the +/-256B short range and relaxes to beqz.

# CHECK-LABEL: <near>:
# CHECK: beqz38 $r0,
# CHECK: j8
near:
	beqz38 $r0, near
	j8 near

# CHECK-LABEL: <far>:
# CHECK: beqz $r0,
# CHECK-NOT: beqz38
far:
	beqz38 $r0, faraway
	.fill 400, 1, 0
faraway:
	nop
