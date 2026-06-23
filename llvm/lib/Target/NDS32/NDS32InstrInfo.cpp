//===-- NDS32InstrInfo.cpp - NDS32 Instruction Information ---------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "NDS32InstrInfo.h"
#include "NDS32.h"
#include "NDS32Subtarget.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/Support/ErrorHandling.h"

using namespace llvm;

#define GET_INSTRINFO_CTOR_DTOR
#include "NDS32GenInstrInfo.inc"

void NDS32InstrInfo::anchor() {}

NDS32InstrInfo::NDS32InstrInfo(NDS32Subtarget &STI)
    : NDS32GenInstrInfo(STI, RI, NDS32::ADJCALLSTACKDOWN,
                        NDS32::ADJCALLSTACKUP),
      RI() {}

void NDS32InstrInfo::storeRegToStackSlot(
    MachineBasicBlock &MBB, MachineBasicBlock::iterator MI, Register SrcReg,
    bool isKill, int FrameIdx, const TargetRegisterClass *RC, Register VReg,
    MachineInstr::MIFlag Flags) const {
  DebugLoc DL;
  if (MI != MBB.end())
    DL = MI->getDebugLoc();

  BuildMI(MBB, MI, DL, get(NDS32::SWI))
      .addReg(SrcReg, getKillRegState(isKill))
      .addFrameIndex(FrameIdx)
      .addImm(0);
}

void NDS32InstrInfo::loadRegFromStackSlot(
    MachineBasicBlock &MBB, MachineBasicBlock::iterator MI, Register DestReg,
    int FrameIdx, const TargetRegisterClass *RC, Register VReg,
    unsigned SubReg, MachineInstr::MIFlag Flags) const {
  DebugLoc DL;
  if (MI != MBB.end())
    DL = MI->getDebugLoc();

  BuildMI(MBB, MI, DL, get(NDS32::LWI), DestReg)
      .addFrameIndex(FrameIdx)
      .addImm(0);
}

void NDS32InstrInfo::copyPhysReg(MachineBasicBlock &MBB,
                                 MachineBasicBlock::iterator I,
                                 const DebugLoc &DL, Register DestReg,
                                 Register SrcReg, bool KillSrc,
                                 bool RenamableDest, bool RenamableSrc) const {
  BuildMI(MBB, I, DL, get(NDS32::ADDri), DestReg)
      .addReg(SrcReg, getKillRegState(KillSrc))
      .addImm(0);
}

bool NDS32InstrInfo::analyzeBranch(MachineBasicBlock &MBB,
                                   MachineBasicBlock *&TBB,
                                   MachineBasicBlock *&FBB,
                                   SmallVectorImpl<MachineOperand> &Cond,
                                   bool AllowModify) const {
  TBB = FBB = nullptr;
  Cond.clear();

  // If the block has no terminators, it just falls into the block after it.
  MachineBasicBlock::iterator I = MBB.getLastNonDebugInstr();
  if (I == MBB.end() || !isUnpredicatedTerminator(*I))
    return false;

  // Count the number of terminators and find the first unconditional branch.
  MachineBasicBlock::iterator FirstUncondBr = MBB.end();
  int NumTerminators = 0;
  for (auto J = I.getReverse(); J != MBB.rend() && isUnpredicatedTerminator(*J); J++) {
    NumTerminators++;
    if (J->getOpcode() == NDS32::BR) {
      FirstUncondBr = J.getReverse();
    }
  }

  // If AllowModify is true, we can erase any terminators after FirstUncondBr.
  if (AllowModify && FirstUncondBr != MBB.end()) {
    while (std::next(FirstUncondBr) != MBB.end()) {
      std::next(FirstUncondBr)->eraseFromParent();
      NumTerminators--;
    }
    I = FirstUncondBr;
  }

  // We can't handle blocks with more than 2 terminators.
  if (NumTerminators > 2)
    return true;

  // Handle a single unconditional branch.
  if (NumTerminators == 1 && I->getOpcode() == NDS32::BR) {
    TBB = I->getOperand(0).getMBB();
    return false;
  }

  // Handle a single conditional branch.
  if (NumTerminators == 1 && I->getDesc().isConditionalBranch()) {
    unsigned Opc = I->getOpcode();
    Cond.push_back(MachineOperand::CreateImm(Opc));
    Cond.push_back(I->getOperand(0));
    if (Opc == NDS32::BEQ || Opc == NDS32::BNE) {
      Cond.push_back(I->getOperand(1));
      TBB = I->getOperand(2).getMBB();
    } else {
      TBB = I->getOperand(1).getMBB();
    }
    return false;
  }

  // Handle a conditional branch followed by an unconditional branch.
  if (NumTerminators == 2 && std::prev(I)->getDesc().isConditionalBranch() &&
      I->getOpcode() == NDS32::BR) {
    MachineBasicBlock::iterator CondBr = std::prev(I);
    unsigned Opc = CondBr->getOpcode();
    Cond.push_back(MachineOperand::CreateImm(Opc));
    Cond.push_back(CondBr->getOperand(0));
    if (Opc == NDS32::BEQ || Opc == NDS32::BNE) {
      Cond.push_back(CondBr->getOperand(1));
      TBB = CondBr->getOperand(2).getMBB();
    } else {
      TBB = CondBr->getOperand(1).getMBB();
    }
    FBB = I->getOperand(0).getMBB();
    return false;
  }

  // Otherwise, we can't handle this.
  return true;
}

unsigned NDS32InstrInfo::removeBranch(MachineBasicBlock &MBB,
                                      int *BytesRemoved) const {
  if (BytesRemoved)
    *BytesRemoved = 0;
  MachineBasicBlock::iterator I = MBB.getLastNonDebugInstr();
  if (I == MBB.end())
    return 0;

  if (I->getOpcode() != NDS32::BR &&
      I->getOpcode() != NDS32::BEQZ && I->getOpcode() != NDS32::BNEZ &&
      I->getOpcode() != NDS32::BGEZ && I->getOpcode() != NDS32::BLTZ &&
      I->getOpcode() != NDS32::BGTZ && I->getOpcode() != NDS32::BLEZ &&
      I->getOpcode() != NDS32::BEQ && I->getOpcode() != NDS32::BNE)
    return 0;

  I->eraseFromParent();
  unsigned Count = 1;

  I = MBB.end();
  if (I == MBB.begin())
    return Count;
  --I;
  if (I->getOpcode() != NDS32::BEQZ && I->getOpcode() != NDS32::BNEZ &&
      I->getOpcode() != NDS32::BGEZ && I->getOpcode() != NDS32::BLTZ &&
      I->getOpcode() != NDS32::BGTZ && I->getOpcode() != NDS32::BLEZ &&
      I->getOpcode() != NDS32::BEQ && I->getOpcode() != NDS32::BNE)
    return Count;

  I->eraseFromParent();
  return Count + 1;
}

unsigned NDS32InstrInfo::insertBranch(MachineBasicBlock &MBB,
                                      MachineBasicBlock *TBB,
                                      MachineBasicBlock *FBB,
                                      ArrayRef<MachineOperand> Cond,
                                      const DebugLoc &DL,
                                      int *BytesAdded) const {
  assert(TBB && "insertBranch must not be told to insert a fallthrough");
  if (BytesAdded)
    *BytesAdded = 0;

  if (Cond.empty()) {
    assert(!FBB && "Unconditional branch with multiple successors!");
    BuildMI(&MBB, DL, get(NDS32::BR)).addMBB(TBB);
    return 1;
  }

  // Conditional branch.
  unsigned Count = 0;
  unsigned Opc = Cond[0].getImm();
  if (Opc == NDS32::BEQ || Opc == NDS32::BNE) {
    BuildMI(&MBB, DL, get(Opc))
        .add(Cond[1])
        .add(Cond[2])
        .addMBB(TBB);
  } else {
    BuildMI(&MBB, DL, get(Opc))
        .add(Cond[1])
        .addMBB(TBB);
  }
  ++Count;

  if (FBB) {
    BuildMI(&MBB, DL, get(NDS32::BR)).addMBB(FBB);
    ++Count;
  }
  return Count;
}

bool NDS32InstrInfo::reverseBranchCondition(
    SmallVectorImpl<MachineOperand> &Cond) const {
  assert(!Cond.empty() && "Invalid branch condition to reverse!");
  unsigned Opc = Cond[0].getImm();
  switch (Opc) {
  default:
    llvm_unreachable("Invalid branch opcode!");
  case NDS32::BEQZ:
    Opc = NDS32::BNEZ;
    break;
  case NDS32::BNEZ:
    Opc = NDS32::BEQZ;
    break;
  case NDS32::BGEZ:
    Opc = NDS32::BLTZ;
    break;
  case NDS32::BLTZ:
    Opc = NDS32::BGEZ;
    break;
  case NDS32::BGTZ:
    Opc = NDS32::BLEZ;
    break;
  case NDS32::BLEZ:
    Opc = NDS32::BGTZ;
    break;
  case NDS32::BEQ:
    Opc = NDS32::BNE;
    break;
  case NDS32::BNE:
    Opc = NDS32::BEQ;
    break;
  }
  Cond[0].setImm(Opc);
  return false;
}

void NDS32InstrInfo::materializeImmediate(MachineBasicBlock &MBB,
                                          MachineBasicBlock::iterator MBBI,
                                          const DebugLoc &DL, Register DstReg,
                                          int64_t Imm) const {
  if (isInt<20>(Imm)) {
    BuildMI(MBB, MBBI, DL, get(NDS32::MOVI), DstReg).addImm(Imm);
    return;
  }
  // sethi loads imm20 << 12; ori fills the low 12 bits.
  BuildMI(MBB, MBBI, DL, get(NDS32::SETHI), DstReg)
      .addImm((static_cast<uint32_t>(Imm) >> 12) & 0xfffff);
  BuildMI(MBB, MBBI, DL, get(NDS32::ORri), DstReg)
      .addReg(DstReg)
      .addImm(static_cast<uint32_t>(Imm) & 0xfff);
}

void NDS32InstrInfo::addImmediate(MachineBasicBlock &MBB,
                                  MachineBasicBlock::iterator MBBI,
                                  const DebugLoc &DL, Register DstReg,
                                  Register SrcReg, int64_t Delta,
                                  Register ScratchReg) const {
  if (Delta == 0) {
    if (DstReg != SrcReg)
      BuildMI(MBB, MBBI, DL, get(NDS32::ADDri), DstReg).addReg(SrcReg).addImm(0);
    return;
  }
  if (isInt<15>(Delta)) {
    BuildMI(MBB, MBBI, DL, get(NDS32::ADDri), DstReg)
        .addReg(SrcReg)
        .addImm(Delta);
    return;
  }
  // Out of addi range: materialize Delta into the scratch register and add by
  // register. $r15 (the reserved assembler temp) is never allocated and so is
  // always free here.
  if (!ScratchReg)
    ScratchReg = NDS32::R15;
  materializeImmediate(MBB, MBBI, DL, ScratchReg, Delta);
  BuildMI(MBB, MBBI, DL, get(NDS32::ADDrr), DstReg)
      .addReg(SrcReg)
      .addReg(ScratchReg);
}
