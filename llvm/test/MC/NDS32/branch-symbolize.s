# RUN: llvm-mc -triple=nds32be -filetype=obj %s -o %t.o
# RUN: llvm-objdump -d --triple=nds32be %t.o | FileCheck %s
#
# The registered MCInstrAnalysis lets llvm-objdump resolve PC-relative branch
# and call targets to absolute addresses / symbols — the key readability win for
# reverse-engineering. Without it, branches print as a bare displacement with no
# <symbol> annotation.

foo:
# CHECK: beqz $r0, {{.*}} <bar>
	beqz $r0, bar
# CHECK: bnez $r1, {{.*}} <foo>
	bnez $r1, foo
back:
# CHECK: j {{.*}} <foo>
	b foo
bar:
# CHECK: beq $r2, $r3, {{.*}} <back>
	beq $r2, $r3, back
