; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s --check-prefix=OFF
; RUN: llc -mtriple=nds32be-unknown-none-elf -nds32-gp-base=0x02034000 < %s \
; RUN:   | FileCheck %s --check-prefix=ON
; Emitted object bytes: the encoder must scale the byte displacement to a word
; field. -211816 -> 0x3c0f3126, which is the mask ROM's own encoding for this
; store apart from the $rt field.
; RUN: llc -mtriple=nds32be-unknown-none-elf -nds32-gp-base=0x02034000 \
; RUN:   -filetype=obj < %s | llvm-objdump -d --triple=nds32be - \
; RUN:   | FileCheck %s --check-prefix=OBJ
;
; OBJ: 3c 0f 31 26  {{.*}}swi.gp {{.*}}-0x33b68
; OBJ: 3c 0d 46 e1  {{.*}}lwi.gp {{.*}}-0x2e47c

; gp-relative addressing of absolute addresses (-nds32-gp-base).
;
; Firmware whose $gp is fixed by its boot ROM can reach a global as a single
; lwi.gp/swi.gp with no base register. That is not just smaller: materializing
; the address with sethi+ori produces a base register that the allocator may
; spill to the frame, and a callee that does not preserve the frame (a ROM
; routine that switches stacks) then makes the reload garbage. With no base
; register there is nothing to spill.
;
; $gp here is 0x02034000, the value the MT6785 conn-MCU's ROM installs.

; 0x02000498 = gp - 0x33b68 (-211816): in range and word-aligned.
define void @in_range_store() {
; OFF-LABEL: in_range_store:
; OFF:       sethi
; OFF:       ori
; OFF-NOT:   swi.gp
;
; ON-LABEL:  in_range_store:
; ON:        swi.gp $r{{[0-9]+}}, [+ -211816]
; ON-NOT:    sethi
  store volatile i32 1, ptr inttoptr (i32 33555608 to ptr)
  ret void
}

; 0x02005984 = gp - 0x2e67c (-189564).
define i32 @in_range_load() {
; ON-LABEL:  in_range_load:
; ON:        lwi.gp $r{{[0-9]+}}, [+ -189564]
  %v = load volatile i32, ptr inttoptr (i32 33577860 to ptr)
  ret i32 %v
}

; The offset field is a signed 17-bit WORD displacement, so anything beyond
; gp +/- 256 KiB must fall back rather than silently truncate. 0x03000000 is far
; outside it.
define void @out_of_range() {
; ON-LABEL:  out_of_range:
; ON:        sethi
; ON-NOT:    swi.gp
  store volatile i32 1, ptr inttoptr (i32 50331648 to ptr)
  ret void
}

; A misaligned address cannot be expressed as a word displacement either.
; 0x02000499 = gp - 0x33b67.
define void @misaligned() {
; ON-LABEL:  misaligned:
; ON-NOT:    swi.gp
  store volatile i8 1, ptr inttoptr (i32 33555609 to ptr)
  ret void
}
