//===-- NDS32MCTargetDesc.cpp - NDS32 Target Descriptions -----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "NDS32MCTargetDesc.h"
#include "NDS32InstPrinter.h"
#include "NDS32MCAsmInfo.h"
#include "TargetInfo/NDS32TargetInfo.h"
#include "llvm/MC/MCAsmBackend.h"
#include "llvm/MC/MCCodeEmitter.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCInstrAnalysis.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCObjectWriter.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCStreamer.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/TargetRegistry.h"

using namespace llvm;

#define GET_INSTRINFO_MC_DESC
#define ENABLE_INSTR_PREDICATE_VERIFIER
#include "NDS32GenInstrInfo.inc"

#define GET_SUBTARGETINFO_MC_DESC
#include "NDS32GenSubtargetInfo.inc"

#define GET_REGINFO_MC_DESC
#include "NDS32GenRegisterInfo.inc"

static MCInstrInfo *createNDS32MCInstrInfo() {
  MCInstrInfo *X = new MCInstrInfo();
  InitNDS32MCInstrInfo(X);
  return X;
}

static MCRegisterInfo *createNDS32MCRegisterInfo(const Triple &TT) {
  MCRegisterInfo *X = new MCRegisterInfo();
  InitNDS32MCRegisterInfo(X, NDS32::R31);
  return X;
}

static MCAsmInfo *createNDS32MCAsmInfo(const MCRegisterInfo &MRI,
                                       const Triple &TT,
                                       const MCTargetOptions &Options) {
  MCAsmInfo *MAI = new NDS32MCAsmInfo(TT);
  return MAI;
}

static MCSubtargetInfo *
createNDS32MCSubtargetInfo(const Triple &TT, StringRef CPU, StringRef FS) {
  return createNDS32MCSubtargetInfoImpl(TT, CPU, /*TuneCPU*/ CPU, FS);
}

static MCInstPrinter *createNDS32MCInstPrinter(const Triple &T,
                                               unsigned SyntaxVariant,
                                               const MCAsmInfo &MAI,
                                               const MCInstrInfo &MII,
                                               const MCRegisterInfo &MRI) {
  if (SyntaxVariant == 0)
    return new NDS32InstPrinter(MAI, MII, MRI);
  return nullptr;
}

namespace {
// Lets llvm-objdump (and other consumers) resolve PC-relative branch/call
// targets to absolute addresses and symbol names — the key readability win for
// reverse-engineering. Direct branch/call targets are encoded as a signed
// displacement in the final operand (the decoder leaves it relative unless a
// symbolizer rewrote it to an expression).
class NDS32MCInstrAnalysis : public MCInstrAnalysis {
public:
  explicit NDS32MCInstrAnalysis(const MCInstrInfo *Info)
      : MCInstrAnalysis(Info) {}

  bool evaluateBranch(const MCInst &Inst, uint64_t Addr, uint64_t Size,
                      uint64_t &Target) const override {
    if (Inst.getNumOperands() == 0)
      return false;
    // Only direct (PC-relative immediate) branches/calls are computable; skip
    // indirect (register) branches and any operand a symbolizer turned into an
    // expression.
    if (!(isBranch(Inst) || isCall(Inst)) || isIndirectBranch(Inst))
      return false;
    const MCOperand &Last = Inst.getOperand(Inst.getNumOperands() - 1);
    if (!Last.isImm())
      return false;
    Target = Addr + Last.getImm();
    return true;
  }
};
} // namespace

static MCInstrAnalysis *createNDS32MCInstrAnalysis(const MCInstrInfo *Info) {
  return new NDS32MCInstrAnalysis(Info);
}

extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeNDS32TargetMC() {
  for (Target *T : {&getTheNDS32Target(), &getTheNDS32leTarget(), &getTheNDS32beTarget()}) {
    TargetRegistry::RegisterMCAsmInfo(*T, createNDS32MCAsmInfo);
    TargetRegistry::RegisterMCInstrInfo(*T, createNDS32MCInstrInfo);
    TargetRegistry::RegisterMCRegInfo(*T, createNDS32MCRegisterInfo);
    TargetRegistry::RegisterMCSubtargetInfo(*T, createNDS32MCSubtargetInfo);
    TargetRegistry::RegisterMCInstPrinter(*T, createNDS32MCInstPrinter);
    TargetRegistry::RegisterMCInstrAnalysis(*T, createNDS32MCInstrAnalysis);
    TargetRegistry::RegisterMCCodeEmitter(*T, createNDS32MCCodeEmitter);
    TargetRegistry::RegisterMCAsmBackend(*T, createNDS32AsmBackend);
  }
}
