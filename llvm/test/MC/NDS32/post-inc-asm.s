# RUN: llvm-mc -triple=nds32be -show-encoding %s | FileCheck %s
# RUN: llvm-mc -triple=nds32le -show-encoding %s | FileCheck %s --check-prefix=ENC
# RUN: llvm-mc -triple=nds32be -show-encoding %s | FileCheck %s --check-prefix=ENC
#
# Post-increment loads/stores must parse the "[$ra]" base as a bare register
# inside literal brackets (previously rejected as "invalid operand"). The
# encoding (ENC) is checked for both nds32be and nds32le: NDS32 instructions are
# always big-endian, so the encoded bytes are identical for both triples.

# CHECK: lwi.bi $r5, [$r6], 4
# ENC: lwi.bi $r5, [$r6], 4    {{.*}}encoding: [0x0c,0x53,0x00,0x01]
	lwi.bi $r5, [$r6], 4

# CHECK: swi.bi $r2, [$r0], -8
# ENC: swi.bi $r2, [$r0], -8   {{.*}}encoding: [0x1c,0x20,0x7f,0xfe]
	swi.bi $r2, [$r0], -8

# CHECK: lbsi.bi $r1, [$r3], 1
# ENC: lbsi.bi $r1, [$r3], 1   {{.*}}encoding: [0x28,0x11,0x80,0x01]
	lbsi.bi $r1, [$r3], 1
