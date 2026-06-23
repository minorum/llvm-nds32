//===-- NDS32FrameLowering.cpp - NDS32 Frame Lowering ---------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "NDS32FrameLowering.h"
#include "NDS32.h"
#include "NDS32InstrInfo.h"
#include "NDS32Subtarget.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/Support/Alignment.h"

using namespace llvm;

NDS32FrameLowering::NDS32FrameLowering(const NDS32Subtarget &STI)
    : TargetFrameLowering(StackGrowsDown, Align(8), 0) {}

void NDS32FrameLowering::emitPrologue(MachineFunction &MF,
                                      MachineBasicBlock &MBB) const {
  const uint64_t StackSize = MF.getFrameInfo().getStackSize();
  if (StackSize == 0)
    return;

  MachineBasicBlock::iterator MBBI = MBB.begin();
  const DebugLoc DL = MBBI != MBB.end() ? MBBI->getDebugLoc() : DebugLoc();
  const NDS32InstrInfo &TII =
      *static_cast<const NDS32InstrInfo *>(MF.getSubtarget().getInstrInfo());

  BuildMI(MBB, MBBI, DL, TII.get(NDS32::ADDri), NDS32::R31)
      .addReg(NDS32::R31)
      .addImm(-static_cast<int64_t>(StackSize));
}

void NDS32FrameLowering::emitEpilogue(MachineFunction &MF,
                                      MachineBasicBlock &MBB) const {
  const uint64_t StackSize = MF.getFrameInfo().getStackSize();
  if (StackSize == 0)
    return;

  MachineBasicBlock::iterator MBBI = MBB.getFirstTerminator();
  const DebugLoc DL = MBBI != MBB.end() ? MBBI->getDebugLoc() : DebugLoc();
  const NDS32InstrInfo &TII =
      *static_cast<const NDS32InstrInfo *>(MF.getSubtarget().getInstrInfo());

  BuildMI(MBB, MBBI, DL, TII.get(NDS32::ADDri), NDS32::R31)
      .addReg(NDS32::R31)
      .addImm(StackSize);
}

MachineBasicBlock::iterator NDS32FrameLowering::eliminateCallFramePseudoInstr(
    MachineFunction &MF, MachineBasicBlock &MBB,
    MachineBasicBlock::iterator I) const {
  const NDS32InstrInfo &TII =
      *static_cast<const NDS32InstrInfo *>(MF.getSubtarget().getInstrInfo());
  if (!hasReservedCallFrame(MF)) {
    int64_t Amount = I->getOperand(0).getImm();
    if (Amount != 0) {
      Amount = alignTo(Amount, getStackAlign());
      if (I->getOpcode() == NDS32::ADJCALLSTACKDOWN) {
        BuildMI(MBB, I, I->getDebugLoc(), TII.get(NDS32::ADDri), NDS32::R31)
            .addReg(NDS32::R31)
            .addImm(-Amount);
      } else {
        BuildMI(MBB, I, I->getDebugLoc(), TII.get(NDS32::ADDri), NDS32::R31)
            .addReg(NDS32::R31)
            .addImm(Amount);
      }
    }
  }
  return MBB.erase(I);
}

bool NDS32FrameLowering::hasFPImpl(const MachineFunction &MF) const {
  return false;
}

bool NDS32FrameLowering::hasReservedCallFrame(const MachineFunction &MF) const {
  return false;
}
