; PIC jump tables. The EK_LabelDifference32 entries (LBB - LJTI) must stay in
; the function's .text section so the difference folds to an assembly-time
; constant — matching the `base + entry` runtime dispatch. If the table lands in
; .rodata (the default ELF behavior), the cross-section difference is emitted as
; a bogus R_NDS32_25_PCREL *branch* relocation applied to data, corrupting the
; table (the dispatch then jumps to garbage). Found by running a switch on the
; nds32 sim under -relocation-model=pic.

; RUN: llc -mtriple=nds32be-unknown-none-elf -relocation-model=pic < %s \
; RUN:   | FileCheck %s
; RUN: llc -mtriple=nds32be-unknown-none-elf -relocation-model=pic -filetype=obj < %s -o %t.o
; RUN: llvm-readobj -r %t.o | FileCheck %s --check-prefix=RELOC

define i32 @jt(i32 %x) {
entry:
  switch i32 %x, label %d [ i32 0, label %a  i32 1, label %b
                            i32 2, label %c  i32 3, label %e  i32 4, label %f ]
a: ret i32 10
b: ret i32 20
c: ret i32 30
e: ret i32 40
f: ret i32 50
d: ret i32 -1
}

; PIC dispatch: table base in a reg, indexed load, add base, jump.
; CHECK-LABEL: jt:
; CHECK:      lw $r{{[0-9]+}}, [$r{{[0-9]+}} + $r{{[0-9]+}} << 2]
; CHECK-NEXT: add $r{{[0-9]+}}, $r{{[0-9]+}}, $r{{[0-9]+}}
; CHECK-NEXT: jr $r{{[0-9]+}}
; The table must remain in .text (no switch to .rodata before it) so the
; label differences fold to constants:
; CHECK-NOT:  .section{{.*}}.rodata
; CHECK:      .LJTI0_0:
; CHECK-NEXT: .long .LBB0_{{[0-9]+}}-.LJTI0_0

; The folded table needs no relocation; in particular it must NOT create the
; branch relocation R_NDS32_25_PCREL on the data words (this function has no
; calls, so any 25_PCREL here would be the bug).
; RELOC-NOT: R_NDS32_25_PCREL
