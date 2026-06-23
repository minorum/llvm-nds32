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
#include "llvm/ADT/BitVector.h"
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
  const bool FP = hasFP(MF);
  if (StackSize == 0 && !FP)
    return;

  const NDS32InstrInfo &TII =
      *static_cast<const NDS32InstrInfo *>(MF.getSubtarget().getInstrInfo());

  // The callee-saved spills (incl. the old $fp) are already at the top of the
  // block, flagged FrameSetup. Insert the $sp adjustment before them so their
  // slots are valid, and flag it FrameSetup too.
  MachineBasicBlock::iterator FirstCSR = MBB.begin();
  const DebugLoc DL =
      FirstCSR != MBB.end() ? FirstCSR->getDebugLoc() : DebugLoc();
  if (StackSize) {
    TII.addImmediate(MBB, FirstCSR, DL, NDS32::R31, NDS32::R31,
                     -static_cast<int64_t>(StackSize));
    for (auto I = MBB.begin(); I != FirstCSR; ++I)
      I->setFlag(MachineInstr::FrameSetup);
  }

  if (FP) {
    // Set the frame pointer to the post-prologue $sp, after the callee-saved
    // spills (so the old $fp has been saved). Fixed locals are then reached via
    // $fp even after a dynamic alloca moves $sp.
    MachineBasicBlock::iterator I = MBB.begin();
    while (I != MBB.end() && I->getFlag(MachineInstr::FrameSetup))
      ++I;
    BuildMI(MBB, I, DL, TII.get(NDS32::ADDri), NDS32::R28)
        .addReg(NDS32::R31)
        .addImm(0)
        .setMIFlag(MachineInstr::FrameSetup);
  }
}

void NDS32FrameLowering::emitEpilogue(MachineFunction &MF,
                                      MachineBasicBlock &MBB) const {
  const uint64_t StackSize = MF.getFrameInfo().getStackSize();
  const bool FP = hasFP(MF);
  if (StackSize == 0 && !FP)
    return;

  MachineBasicBlock::iterator MBBI = MBB.getFirstTerminator();
  const DebugLoc DL = MBBI != MBB.end() ? MBBI->getDebugLoc() : DebugLoc();
  const NDS32InstrInfo &TII =
      *static_cast<const NDS32InstrInfo *>(MF.getSubtarget().getInstrInfo());

  if (FP) {
    // Restore $sp to the post-prologue position (undoing any dynamic alloca)
    // before the callee-saved reloads, which are $sp-relative: $sp = $fp. The
    // reloads are the FrameDestroy instructions just before the terminator.
    MachineBasicBlock::iterator I = MBBI;
    while (I != MBB.begin() && std::prev(I)->getFlag(MachineInstr::FrameDestroy))
      --I;
    BuildMI(MBB, I, DL, TII.get(NDS32::ADDri), NDS32::R31)
        .addReg(NDS32::R28)
        .addImm(0)
        .setMIFlag(MachineInstr::FrameDestroy);
  }

  // Deallocate the fixed frame after the callee-saved reloads.
  if (StackSize)
    TII.addImmediate(MBB, MBBI, DL, NDS32::R31, NDS32::R31,
                     static_cast<int64_t>(StackSize));
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
      if (I->getOpcode() == NDS32::ADJCALLSTACKDOWN)
        Amount = -Amount;
      TII.addImmediate(MBB, I, I->getDebugLoc(), NDS32::R31, NDS32::R31, Amount);
    }
  }
  return MBB.erase(I);
}

bool NDS32FrameLowering::hasFPImpl(const MachineFunction &MF) const {
  // A frame pointer ($r28) is needed when the stack frame size is not constant
  // (dynamic alloca) or the frame address is taken, so fixed locals remain
  // reachable from a stable register after $sp moves.
  const MachineFrameInfo &MFI = MF.getFrameInfo();
  return MFI.hasVarSizedObjects() || MFI.isFrameAddressTaken();
}

bool NDS32FrameLowering::hasReservedCallFrame(const MachineFunction &MF) const {
  // With dynamic stack objects $sp is not constant, so call-argument areas are
  // allocated/freed around each call rather than reserved up front.
  return !MF.getFrameInfo().hasVarSizedObjects();
}

void NDS32FrameLowering::determineCalleeSaves(MachineFunction &MF,
                                              BitVector &SavedRegs,
                                              RegScavenger *RS) const {
  TargetFrameLowering::determineCalleeSaves(MF, SavedRegs, RS);
  // The frame-pointer setup clobbers $r28 (which is not visible to the generic
  // clobber analysis since it is inserted later), so force it to be saved.
  if (hasFP(MF))
    SavedRegs.set(NDS32::R28);
}

// Spill the callee-saved registers, flagging each store FrameSetup. The flag
// keeps them $sp-relative in eliminateFrameIndex (the frame pointer is not set
// up until after this region) and lets emitPrologue position the FP setup after
// them, so the old $fp is saved before $r28 is overwritten.
bool NDS32FrameLowering::spillCalleeSavedRegisters(
    MachineBasicBlock &MBB, MachineBasicBlock::iterator MI,
    ArrayRef<CalleeSavedInfo> CSI, const TargetRegisterInfo *TRI) const {
  if (CSI.empty())
    return true;
  MachineFunction &MF = *MBB.getParent();
  const NDS32InstrInfo &TII =
      *static_cast<const NDS32InstrInfo *>(MF.getSubtarget().getInstrInfo());
  const DebugLoc DL = MI != MBB.end() ? MI->getDebugLoc() : DebugLoc();
  for (const CalleeSavedInfo &CS : CSI) {
    Register Reg = CS.getReg();
    const TargetRegisterClass *RC = TRI->getMinimalPhysRegClass(Reg);
    TII.storeRegToStackSlot(MBB, MI, Reg, /*isKill=*/true, CS.getFrameIdx(), RC,
                            Register());
    std::prev(MI)->setFlag(MachineInstr::FrameSetup);
  }
  return true;
}

// Restore the callee-saved registers, flagging each load FrameDestroy so it is
// $sp-relative (emitEpilogue restores $sp from $fp before this region).
bool NDS32FrameLowering::restoreCalleeSavedRegisters(
    MachineBasicBlock &MBB, MachineBasicBlock::iterator MI,
    MutableArrayRef<CalleeSavedInfo> CSI, const TargetRegisterInfo *TRI) const {
  if (CSI.empty())
    return true;
  MachineFunction &MF = *MBB.getParent();
  const NDS32InstrInfo &TII =
      *static_cast<const NDS32InstrInfo *>(MF.getSubtarget().getInstrInfo());
  const DebugLoc DL = MI != MBB.end() ? MI->getDebugLoc() : DebugLoc();
  for (const CalleeSavedInfo &CS : CSI) {
    Register Reg = CS.getReg();
    const TargetRegisterClass *RC = TRI->getMinimalPhysRegClass(Reg);
    TII.loadRegFromStackSlot(MBB, MI, Reg, CS.getFrameIdx(), RC, Register());
    std::prev(MI)->setFlag(MachineInstr::FrameDestroy);
  }
  return true;
}
