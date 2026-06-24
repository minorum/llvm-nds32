# A backward (negative-displacement) unconditional branch must encode as
# `b`/j (opcode 0x48), NOT `jal` (0x49). The j/jal pair differ in bit 24 (the
# link bit) and the displacement field is only 24 bits [23:0] — the "25" in
# fixup_nds32_25_pcrel is the disp<<1 range. A too-wide (25-bit) fixup mask let
# a negative displacement's sign bit flip `b` into `jal`, clobbering $lp and
# corrupting the return. Found by running Rust core::fmt on the nds32 sim
# (integer formatting infinite-looped via a back-edge that became a call).

# RUN: llvm-mc -triple=nds32be-unknown-none-elf -filetype=obj %s -o %t.o
# RUN: llvm-objdump -d --triple=nds32be-unknown-none-elf %t.o | FileCheck %s

target:
	nop
	nop
	b target

# The branch is 8 bytes back; it must stay `j` (0x48..), not become `jal`.
# CHECK:      8: 48 {{[0-9a-f]+}} {{[0-9a-f]+}} {{[0-9a-f]+}} {{.*}}j
# CHECK-NOT:  jal
