; RUN: llc -mtriple=nds32be-unknown-none-elf -mcpu=v2 < %s \
; RUN:   | FileCheck %s --check-prefix=V2
; RUN: llc -mtriple=nds32be-unknown-none-elf -mcpu=v3 < %s \
; RUN:   | FileCheck %s --check-prefix=V3
;
; `bitci rt, ra, imm15` (rt = ra & ~zext(imm15)) is V3-baseline only. A V2 core
; TRAPS on it as an illegal instruction -- on the MT6785 conn-MCU this jumped to
; the ROM fatal-halt loop at 0xf000b17c and was the step-5 CONN_BLK2 boot
; blocker. The stock firmware never emits it (it uses bclr there), and
; `nds32be-elf-as -march=v2` rejects it outright.
;
; So the (and reg, imm) -> BITCI pattern must be gated on HasV3Ops. V2 lowers
; the same expression via movi + and.

define i32 @clear_bits(i32 %x) {
; V2: clear_bits:
; V2: movi $r1, -8714
; V2: and $r0, $r0, $r1
; V2-NOT: bitci
;
; V3: clear_bits:
; V3: bitci $r0, $r0, 8713
  %r = and i32 %x, -8714                  ; x & ~0x2209
  ret i32 %r
}
