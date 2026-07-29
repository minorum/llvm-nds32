; RUN: llc -mtriple=nds32be-unknown-none-elf -mcpu=v2 < %s \
; RUN:   | FileCheck %s --check-prefix=FULL
; RUN: llc -mtriple=nds32be-unknown-none-elf -mcpu=v2 -mattr=+reduced-regs < %s \
; RUN:   | FileCheck %s --check-prefix=REDUCED
;
; A reduced-register core (Andes -mreduced-regs; the MT6785 conn-MCU is one)
; implements only r0-r10, r15 and r28-r31. Allocating r11-r14 or r16-r27 there
; produces code that FAULTS on hardware, and nothing downstream diagnoses it --
; so this test asserts on the register set, not on instruction selection.
;
; The volatile loads/stores cannot be reordered relative to each other, so all
; 24 loaded values are simultaneously live and the allocator is forced to use
; every register it believes exists (or spill).

@g = external global [64 x i32]

define void @pressure() {
; FULL: pressure:
; FULL: $r11
;
; REDUCED: pressure:
; REDUCED-NOT: $r11
; REDUCED-NOT: $r12
; REDUCED-NOT: $r13
; REDUCED-NOT: $r14
; REDUCED-NOT: $r16
; REDUCED-NOT: $r17
; REDUCED-NOT: $r18
; REDUCED-NOT: $r19
; REDUCED-NOT: $r20
; REDUCED-NOT: $r21
; REDUCED-NOT: $r22
; REDUCED-NOT: $r23
; REDUCED-NOT: $r24
; REDUCED-NOT: $r25
; REDUCED-NOT: $r26
; REDUCED-NOT: $r27
  %v0 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 0)
  %v1 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 1)
  %v2 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 2)
  %v3 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 3)
  %v4 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 4)
  %v5 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 5)
  %v6 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 6)
  %v7 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 7)
  %v8 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 8)
  %v9 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 9)
  %v10 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 10)
  %v11 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 11)
  %v12 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 12)
  %v13 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 13)
  %v14 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 14)
  %v15 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 15)
  %v16 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 16)
  %v17 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 17)
  %v18 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 18)
  %v19 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 19)
  %v20 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 20)
  %v21 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 21)
  %v22 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 22)
  %v23 = load volatile i32, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 23)
  store volatile i32 %v0, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 32)
  store volatile i32 %v1, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 33)
  store volatile i32 %v2, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 34)
  store volatile i32 %v3, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 35)
  store volatile i32 %v4, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 36)
  store volatile i32 %v5, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 37)
  store volatile i32 %v6, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 38)
  store volatile i32 %v7, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 39)
  store volatile i32 %v8, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 40)
  store volatile i32 %v9, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 41)
  store volatile i32 %v10, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 42)
  store volatile i32 %v11, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 43)
  store volatile i32 %v12, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 44)
  store volatile i32 %v13, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 45)
  store volatile i32 %v14, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 46)
  store volatile i32 %v15, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 47)
  store volatile i32 %v16, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 48)
  store volatile i32 %v17, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 49)
  store volatile i32 %v18, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 50)
  store volatile i32 %v19, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 51)
  store volatile i32 %v20, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 52)
  store volatile i32 %v21, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 53)
  store volatile i32 %v22, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 54)
  store volatile i32 %v23, ptr getelementptr([64 x i32], ptr @g, i32 0, i32 55)
  ret void
}
