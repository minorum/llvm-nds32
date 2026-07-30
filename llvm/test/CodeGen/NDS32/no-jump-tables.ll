; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s --check-prefix=JT
; RUN: llc -mtriple=nds32be-unknown-none-elf -nds32-no-jump-tables < %s \
; RUN:   | FileCheck %s --check-prefix=NOJT

; -nds32-no-jump-tables suppresses jump-table formation, so a dense switch is
; lowered to a compare-and-branch chain instead of "load target from table; jr".
;
; It exists for targets that cannot read their own read-only data back as 32-bit
; words. On the MT6785 conn-MCU the EMI port byte-swaps 32-bit accesses: data the
; core wrote itself round-trips (the swap cancels), but read-only data placed
; there by an external loader was never swapped, so a word load returns it
; byte-reversed. For an ordinary constant that is a wrong value; for a jump table
; it is `jr` to a byte-reversed pointer — an indirect branch to an arbitrary
; address, and since `jr` does not write $lp the fault is reported against
; whoever called the function, not the function itself.

declare void @sink(i32)

define i32 @dense_switch(i32 %x) {
; JT-LABEL:   dense_switch:
; JT:          lw $r{{[0-9]+}}, [$r{{[0-9]+}} + $r{{[0-9]+}} << 2]
; JT:          jr $r{{[0-9]+}}
;
; NOJT-LABEL: dense_switch:
; NOJT-NOT:    lw $r{{[0-9]+}}, [$r{{[0-9]+}} + $r{{[0-9]+}} << 2]
; NOJT-NOT:    jr $r
; NOJT:        {{beq|bne}}
entry:
  switch i32 %x, label %def [ i32 1, label %b1
                              i32 2, label %b2
                              i32 3, label %b3
                              i32 4, label %b4
                              i32 5, label %b5
                              i32 6, label %b6 ]
b1: call void @sink(i32 11) br label %def
b2: call void @sink(i32 12) br label %def
b3: call void @sink(i32 13) br label %def
b4: call void @sink(i32 14) br label %def
b5: call void @sink(i32 15) br label %def
b6: call void @sink(i32 16) br label %def
def: ret i32 0
}

; A jump table is only ever an optimisation, so suppressing it must not change
; behaviour — the default arm still has to be reachable for out-of-range values.
define i32 @out_of_range(i32 %x) {
; NOJT-LABEL: out_of_range:
; NOJT-NOT:    jr $r
  switch i32 %x, label %def [ i32 1, label %b1
                              i32 2, label %b2
                              i32 3, label %b3
                              i32 4, label %b4 ]
b1: ret i32 101
b2: ret i32 102
b3: ret i32 103
b4: ret i32 104
def: ret i32 -1
}
