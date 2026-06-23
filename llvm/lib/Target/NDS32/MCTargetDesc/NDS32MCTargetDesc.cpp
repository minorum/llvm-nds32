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

extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeNDS32TargetMC() {
  for (Target *T : {&getTheNDS32Target(), &getTheNDS32leTarget(), &getTheNDS32beTarget()}) {
    TargetRegistry::RegisterMCAsmInfo(*T, createNDS32MCAsmInfo);
    TargetRegistry::RegisterMCInstrInfo(*T, createNDS32MCInstrInfo);
    TargetRegistry::RegisterMCRegInfo(*T, createNDS32MCRegisterInfo);
    TargetRegistry::RegisterMCSubtargetInfo(*T, createNDS32MCSubtargetInfo);
    TargetRegistry::RegisterMCInstPrinter(*T, createNDS32MCInstPrinter);
    TargetRegistry::RegisterMCCodeEmitter(*T, createNDS32MCCodeEmitter);
    TargetRegistry::RegisterMCAsmBackend(*T, createNDS32AsmBackend);
  }
}
