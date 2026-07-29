//===-- NDS32RegisterInfo.cpp - NDS32 Register Information ----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "NDS32RegisterInfo.h"
#include "NDS32.h"
#include "NDS32FrameLowering.h"
#include "NDS32InstrInfo.h"
#include "NDS32Subtarget.h"
#include "llvm/ADT/BitVector.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/Support/ErrorHandling.h"

using namespace llvm;

#define GET_REGINFO_TARGET_DESC
#include "NDS32GenRegisterInfo.inc"

NDS32RegisterInfo::NDS32RegisterInfo()
    : NDS32GenRegisterInfo(NDS32::R30) {}

const MCPhysReg *
NDS32RegisterInfo::getCalleeSavedRegs(const MachineFunction *MF) const {
  static const MCPhysReg CalleeSavedRegs[] = {
      NDS32::R6, NDS32::R7, NDS32::R8, NDS32::R9,
      NDS32::R10, NDS32::R11, NDS32::R12, NDS32::R13,
      NDS32::R14, NDS32::R28, NDS32::R30,
      0
  };
  // A reduced-register core has no r11-r14 to save.
  static const MCPhysReg CalleeSavedRegsReduced[] = {
      NDS32::R6, NDS32::R7, NDS32::R8, NDS32::R9,
      NDS32::R10, NDS32::R28, NDS32::R30,
      0
  };
  if (MF && MF->getSubtarget<NDS32Subtarget>().hasReducedRegs())
    return CalleeSavedRegsReduced;
  return CalleeSavedRegs;
}

const uint32_t *
NDS32RegisterInfo::getCallPreservedMask(const MachineFunction &MF,
                                        CallingConv::ID CC) const {
  if (MF.getSubtarget<NDS32Subtarget>().hasReducedRegs())
    return CSR_NDS32_Reduced_RegMask;
  return CSR_NDS32_RegMask;
}

BitVector NDS32RegisterInfo::getReservedRegs(const MachineFunction &MF) const {
  BitVector Reserved(getNumRegs());
  Reserved.set(NDS32::R15); // Reserved for assembler temporary.
  Reserved.set(NDS32::R24);
  Reserved.set(NDS32::R25);
  Reserved.set(NDS32::R26);
  Reserved.set(NDS32::R27);
  Reserved.set(NDS32::R28); // FP
  Reserved.set(NDS32::R29); // GP
  Reserved.set(NDS32::R30); // LP
  Reserved.set(NDS32::R31); // SP
  // On a reduced-register core (FeatureReducedRegs) only r0-r10, r15 and
  // r28-r31 are implemented, so everything else must be off-limits to the
  // allocator. Touching r11-r14 or r16-r27 there yields code that faults --
  // and nothing else in the pipeline would catch it.
  // Listed explicitly, NOT as a numeric range: the generated register enum is
  // ordered by record *name*, so R16..R23 would sweep in R2.
  if (MF.getSubtarget<NDS32Subtarget>().hasReducedRegs()) {
    static const MCPhysReg Absent[] = {
        NDS32::R11, NDS32::R12, NDS32::R13, NDS32::R14,
        NDS32::R16, NDS32::R17, NDS32::R18, NDS32::R19,
        NDS32::R20, NDS32::R21, NDS32::R22, NDS32::R23,
    };
    for (MCPhysReg R : Absent)
      Reserved.set(R);
  }
  return Reserved;
}

const TargetRegisterClass *
NDS32RegisterInfo::getPointerRegClass(unsigned Kind) const {
  return &NDS32::GPRRegClass;
}

bool NDS32RegisterInfo::eliminateFrameIndex(MachineBasicBlock::iterator II,
                                            int SPAdj, unsigned FIOperandNum,
                                            RegScavenger *RS) const {
  MachineInstr &MI = *II;
  MachineBasicBlock &MBB = *MI.getParent();
  MachineFunction &MF = *MBB.getParent();
  const NDS32InstrInfo &TII =
      *static_cast<const NDS32InstrInfo *>(MF.getSubtarget().getInstrInfo());
  const NDS32FrameLowering &TFI =
      *static_cast<const NDS32FrameLowering *>(
          MF.getSubtarget().getFrameLowering());

  int FrameIndex = MI.getOperand(FIOperandNum).getIndex();
  // The frame pointer ($r28) holds the post-prologue stack pointer, so FP- and
  // $sp-relative displacements of a fixed object are identical: objectOffset +
  // whole frame. The trailing immediate operand (e.g. a struct-field byte
  // offset) is preserved rather than overwritten.
  int64_t Offset = MF.getFrameInfo().getObjectOffset(FrameIndex) +
                   MF.getFrameInfo().getStackSize() +
                   MI.getOperand(FIOperandNum + 1).getImm();
  // Normal locals use $fp when present (it is stable across a dynamic alloca
  // that moves $sp); the callee-saved spills/reloads (FrameSetup/FrameDestroy)
  // run while $fp is not yet/no longer valid, so they stay $sp-relative.
  bool IsCSRAccess = MI.getFlag(MachineInstr::FrameSetup) ||
                     MI.getFlag(MachineInstr::FrameDestroy);
  Register BaseReg =
      (TFI.hasFP(MF) && !IsCSRAccess) ? NDS32::R28 : NDS32::R31;

  // If the offset fits the instruction's signed 15-bit field, fold it directly.
  if (isInt<15>(Offset)) {
    MI.getOperand(FIOperandNum).ChangeToRegister(BaseReg, false);
    MI.getOperand(FIOperandNum + 1).ChangeToImmediate(Offset);
    return false;
  }

  // Otherwise compute the effective address into the reserved scratch register
  // ($r15) and use a zero displacement, avoiding silent truncation.
  const DebugLoc &DL = MI.getDebugLoc();
  TII.addImmediate(MBB, II, DL, NDS32::R15, BaseReg, Offset);
  MI.getOperand(FIOperandNum).ChangeToRegister(NDS32::R15, false);
  MI.getOperand(FIOperandNum + 1).ChangeToImmediate(0);
  return false;
}

Register NDS32RegisterInfo::getFrameRegister(const MachineFunction &MF) const {
  return NDS32::R31; // SP as frame register
}
