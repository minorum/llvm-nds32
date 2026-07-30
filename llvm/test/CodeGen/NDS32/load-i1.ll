; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s

; An in-memory i1 is a byte holding 0 or 1, so an i1 load promotes to a byte
; load. Without that promotion this fails to select outright:
;   Cannot select: load (s8), zext from i1
; which is reachable from a plain `static mut FLAG: bool` in Rust — a global
; boolean is ordinary code, not a corner case.

@flag = internal global i1 false

; A zero-extending load needs no fixup at all: the byte already is 0 or 1.
define i32 @load_bool_zext() {
; CHECK-LABEL: load_bool_zext:
; CHECK:       lbi $r{{[0-9]+}}, [$r{{[0-9]+}} + 0]
; CHECK-NEXT:  ret
  %v = load i1, ptr @flag
  %z = zext i1 %v to i32
  ret i32 %z
}

; Sign-extending one bit has no instruction (SIGN_EXTEND_INREG i1 is Expand),
; so it becomes mask-then-negate: 0 -> 0, 1 -> -1.
define i32 @load_bool_sext() {
; CHECK-LABEL: load_bool_sext:
; CHECK:       lbi
; CHECK:       andi $r{{[0-9]+}}, $r{{[0-9]+}}, 1
; CHECK:       sub
  %v = load i1, ptr @flag
  %s = sext i1 %v to i32
  ret i32 %s
}

; Branching on a loaded boolean is the shape the firmware actually hits.
define i32 @branch_on_bool(i32 %a, i32 %b) {
; CHECK-LABEL: branch_on_bool:
; CHECK:       lbi
  %v = load i1, ptr @flag
  %r = select i1 %v, i32 %a, i32 %b
  ret i32 %r
}
