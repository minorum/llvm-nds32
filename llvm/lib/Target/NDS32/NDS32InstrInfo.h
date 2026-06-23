//===-- NDS32InstrInfo.h - NDS32 Instruction Information --------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_NDS32_NDS32INSTRINFO_H
#define LLVM_LIB_TARGET_NDS32_NDS32INSTRINFO_H

#include "NDS32RegisterInfo.h"
#include "llvm/CodeGen/TargetInstrInfo.h"

#define GET_INSTRINFO_HEADER
#include "NDS32GenInstrInfo.inc"

namespace llvm {

class NDS32Subtarget;

class NDS32InstrInfo : public NDS32GenInstrInfo {
  const NDS32RegisterInfo RI;
  virtual void anchor();

public:
  explicit NDS32InstrInfo(NDS32Subtarget &STI);

  const NDS32RegisterInfo &getRegisterInfo() const { return RI; }

  void copyPhysReg(MachineBasicBlock &MBB, MachineBasicBlock::iterator I,
                   const DebugLoc &DL, Register DestReg, Register SrcReg,
                   bool KillSrc, bool RenamableDest = false,
                   bool RenamableSrc = false) const override;

  void storeRegToStackSlot(MachineBasicBlock &MBB,
                           MachineBasicBlock::iterator MI, Register SrcReg,
                           bool isKill, int FrameIndex,
                           const TargetRegisterClass *RC, Register VReg,
                           MachineInstr::MIFlag Flags =
                               MachineInstr::NoFlags) const override;

  void loadRegFromStackSlot(MachineBasicBlock &MBB,
                            MachineBasicBlock::iterator MI, Register DestReg,
                            int FrameIdx, const TargetRegisterClass *RC,
                            Register VReg, unsigned SubReg = 0,
                            MachineInstr::MIFlag Flags =
                                MachineInstr::NoFlags) const override;

  bool analyzeBranch(MachineBasicBlock &MBB, MachineBasicBlock *&TBB,
                     MachineBasicBlock *&FBB,
                     SmallVectorImpl<MachineOperand> &Cond,
                     bool AllowModify = false) const override;

  unsigned removeBranch(MachineBasicBlock &MBB,
                        int *BytesRemoved = nullptr) const override;

  unsigned insertBranch(MachineBasicBlock &MBB, MachineBasicBlock *TBB,
                        MachineBasicBlock *FBB, ArrayRef<MachineOperand> Cond,
                        const DebugLoc &DL,
                        int *BytesAdded = nullptr) const override;

  bool reverseBranchCondition(
      SmallVectorImpl<MachineOperand> &Cond) const override;

  // Materialize an arbitrary 32-bit immediate into DstReg: a single movi when
  // it fits the signed 20-bit field, otherwise sethi(hi20)+ori(lo12).
  void materializeImmediate(MachineBasicBlock &MBB,
                            MachineBasicBlock::iterator MBBI, const DebugLoc &DL,
                            Register DstReg, int64_t Imm) const;

  // Emit DstReg = SrcReg + Delta, using a single addi when Delta fits the
  // signed 15-bit field, otherwise materializing Delta into ScratchReg and
  // adding by register. ScratchReg defaults to the reserved assembler temp
  // ($r15) when left empty.
  void addImmediate(MachineBasicBlock &MBB, MachineBasicBlock::iterator MBBI,
                    const DebugLoc &DL, Register DstReg, Register SrcReg,
                    int64_t Delta, Register ScratchReg = Register()) const;
};

} // namespace llvm

#endif // LLVM_LIB_TARGET_NDS32_NDS32INSTRINFO_H
