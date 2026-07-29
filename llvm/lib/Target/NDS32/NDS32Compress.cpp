//===-- NDS32Compress.cpp - Replace 32-bit ops with 16-bit forms ---------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// A post-RA peephole that rewrites eligible 32-bit instructions into their
// 16-bit (compressed) equivalents to shrink .text. Only the forms whose operand
// ranges are fully verified are emitted; non-branch only, so no relaxation is
// needed (branch compression would require it and is left out).
//
//===----------------------------------------------------------------------===//

#include "NDS32.h"
#include "NDS32InstrInfo.h"
#include "NDS32Subtarget.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"

using namespace llvm;

#define DEBUG_TYPE "nds32-compress"

namespace {
class NDS32Compress : public MachineFunctionPass {
  const NDS32InstrInfo *TII = nullptr;
  const TargetRegisterInfo *TRI = nullptr;

  // Hardware register number (0-31).
  unsigned enc(const MachineOperand &MO) const {
    return TRI->getEncodingValue(MO.getReg());
  }
  bool low8(const MachineOperand &MO) const { return enc(MO) < 8; }
  // Encodable in the add45/addi45 4-bit register field: r0-r11 or r16-r19.
  bool gpr4(const MachineOperand &MO) const {
    unsigned R = enc(MO);
    return R <= 11 || (R >= 16 && R <= 19);
  }

public:
  static char ID;
  NDS32Compress() : MachineFunctionPass(ID) {}
  bool runOnMachineFunction(MachineFunction &MF) override;
  StringRef getPassName() const override {
    return "NDS32 16-bit compression";
  }
};
} // namespace

char NDS32Compress::ID = 0;

bool NDS32Compress::runOnMachineFunction(MachineFunction &MF) {
  const NDS32Subtarget &STI = MF.getSubtarget<NDS32Subtarget>();
  // A "+no-16bit" core must never see a compressed form.
  if (!STI.has16Bit())
    return false;
  TII = STI.getInstrInfo();
  TRI = STI.getRegisterInfo();
  bool Changed = false;

  for (MachineBasicBlock &MBB : MF) {
    for (MachineInstr &MI : llvm::make_early_inc_range(MBB)) {
      const DebugLoc &DL = MI.getDebugLoc();
      MachineInstrBuilder New;
      switch (MI.getOpcode()) {
      default:
        continue;
      case NDS32::BEQZ:
      case NDS32::BNEZ: {
        // beqz/bnez $rt, target -> 16-bit beqz38/bnez38 when $rt is in $r0-$r7.
        // The assembler relaxes back to the 32-bit form if the target is out of
        // the +/-256B short-branch range.
        const MachineOperand &Rt = MI.getOperand(0);
        if (!Rt.isReg() || !low8(Rt))
          continue;
        unsigned NewOpc =
            MI.getOpcode() == NDS32::BEQZ ? NDS32::BEQZ38 : NDS32::BNEZ38;
        New = BuildMI(MBB, MI, DL, TII->get(NewOpc))
                  .add(Rt).add(MI.getOperand(1));
        break;
      }
      case NDS32::BR: {
        // Unconditional b target -> 16-bit j8 (relaxed back if out of range).
        New = BuildMI(MBB, MI, DL, TII->get(NDS32::J8)).add(MI.getOperand(0));
        break;
      }
      case NDS32::ADDrr: {
        // add $rt, $ra, $rb  ->  add45 $rt, $rb  when $rt is a source and is in
        // the 4-bit register subset (commutative, so try either source).
        const MachineOperand &Rt = MI.getOperand(0);
        const MachineOperand &Ra = MI.getOperand(1);
        const MachineOperand &Rb = MI.getOperand(2);
        if (!gpr4(Rt))
          continue;
        Register Dst = Rt.getReg();
        if (Ra.getReg() == Dst)
          New = BuildMI(MBB, MI, DL, TII->get(NDS32::ADD45))
                    .addReg(Dst, RegState::Define).addReg(Dst).add(Rb);
        else if (Rb.getReg() == Dst)
          New = BuildMI(MBB, MI, DL, TII->get(NDS32::ADD45))
                    .addReg(Dst, RegState::Define).addReg(Dst).add(Ra);
        else
          continue;
        break;
      }
      case NDS32::ADDri: {
        const MachineOperand &Rt = MI.getOperand(0);
        const MachineOperand &Ra = MI.getOperand(1);
        if (!MI.getOperand(2).isImm())
          continue;
        int64_t Imm = MI.getOperand(2).getImm();
        if (Imm == 0) {
          // Register copy -> mov55 (5-bit regs).
          New = BuildMI(MBB, MI, DL, TII->get(NDS32::MOV55)).add(Rt).add(Ra);
        } else if (low8(Rt) && low8(Ra) && Imm >= 0 && Imm <= 7) {
          New = BuildMI(MBB, MI, DL, TII->get(NDS32::ADDI333))
                    .add(Rt).add(Ra).addImm(Imm);
        } else if (Rt.getReg() == Ra.getReg() && gpr4(Rt) && Imm >= 0 &&
                   Imm <= 31) {
          // addi $rt, $rt, imm5u  ->  addi45 $rt, imm  (read-modify-write).
          New = BuildMI(MBB, MI, DL, TII->get(NDS32::ADDI45))
                    .addReg(Rt.getReg(), RegState::Define)
                    .addReg(Rt.getReg()).addImm(Imm);
        } else {
          continue;
        }
        break;
      }
      case NDS32::MOVI: {
        const MachineOperand &Rt = MI.getOperand(0);
        if (!MI.getOperand(1).isImm())
          continue;
        int64_t Imm = MI.getOperand(1).getImm();
        if (Imm < -16 || Imm > 15)
          continue;
        New = BuildMI(MBB, MI, DL, TII->get(NDS32::MOVI55)).add(Rt).addImm(Imm);
        break;
      }
      case NDS32::LWI: {
        const MachineOperand &Rt = MI.getOperand(0);
        const MachineOperand &Ra = MI.getOperand(1);
        if (!MI.getOperand(2).isImm())
          continue;
        int64_t Imm = MI.getOperand(2).getImm();
        if (!low8(Rt) || !low8(Ra) || Imm < 0 || Imm > 28 || (Imm & 3))
          continue;
        New = BuildMI(MBB, MI, DL, TII->get(NDS32::LWI333))
                  .add(Rt).add(Ra).addImm(Imm);
        break;
      }
      case NDS32::SWI: {
        const MachineOperand &Rt = MI.getOperand(0);
        const MachineOperand &Ra = MI.getOperand(1);
        if (!MI.getOperand(2).isImm())
          continue;
        int64_t Imm = MI.getOperand(2).getImm();
        if (!low8(Rt) || !low8(Ra) || Imm < 0 || Imm > 28 || (Imm & 3))
          continue;
        New = BuildMI(MBB, MI, DL, TII->get(NDS32::SWI333))
                  .add(Rt).add(Ra).addImm(Imm);
        break;
      }
      }
      (void)New;
      MI.eraseFromParent();
      Changed = true;
    }
  }
  return Changed;
}

FunctionPass *llvm::createNDS32CompressPass() { return new NDS32Compress(); }
