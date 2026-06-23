//===-- NDS32RegisterInfo.cpp - NDS32 Register Information ----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "NDS32RegisterInfo.h"
#include "NDS32.h"
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
  return CalleeSavedRegs;
}

const uint32_t *
NDS32RegisterInfo::getCallPreservedMask(const MachineFunction &MF,
                                        CallingConv::ID CC) const {
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
  MachineFunction &MF = *MI.getParent()->getParent();
  int FrameIndex = MI.getOperand(FIOperandNum).getIndex();
  int Offset = MF.getFrameInfo().getObjectOffset(FrameIndex) +
               MF.getFrameInfo().getStackSize();

  MI.getOperand(FIOperandNum).ChangeToRegister(NDS32::R31, false);
  MI.getOperand(FIOperandNum + 1).ChangeToImmediate(Offset);
  return false;
}

Register NDS32RegisterInfo::getFrameRegister(const MachineFunction &MF) const {
  return NDS32::R31; // SP as frame register
}
