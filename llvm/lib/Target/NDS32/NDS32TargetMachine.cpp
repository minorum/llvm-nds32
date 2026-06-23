//===-- NDS32TargetMachine.cpp - Define TargetMachine for NDS32 -----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "NDS32TargetMachine.h"
#include "NDS32.h"
#include "NDS32MachineFunctionInfo.h"
#include "TargetInfo/NDS32TargetInfo.h"
#include "llvm/CodeGen/Passes.h"
#include "llvm/CodeGen/TargetLoweringObjectFileImpl.h"
#include "llvm/CodeGen/TargetPassConfig.h"
#include "llvm/MC/TargetRegistry.h"
#include <optional>

using namespace llvm;

extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeNDS32Target() {
  RegisterTargetMachine<NDS32TargetMachine> X(getTheNDS32Target());
  RegisterTargetMachine<NDS32TargetMachine> Y(getTheNDS32leTarget());
  RegisterTargetMachine<NDS32TargetMachine> Z(getTheNDS32beTarget());
}

static Reloc::Model getEffectiveRelocModel(std::optional<Reloc::Model> RM) {
  return RM.value_or(Reloc::Static);
}

static std::string computeDataLayout(const Triple &TT, StringRef CPU,
                                     const TargetOptions &Options) {
  if (TT.isLittleEndian())
    return "e-m:e-p:32:32-i64:64-n32-S32";
  return "E-m:e-p:32:32-i64:64-n32-S32";
}

NDS32TargetMachine::NDS32TargetMachine(const Target &T, const Triple &TT,
                                       StringRef CPU, StringRef FS,
                                       const TargetOptions &Options,
                                       std::optional<Reloc::Model> RM,
                                       std::optional<CodeModel::Model> CM,
                                       CodeGenOptLevel OL, bool JIT)
    : CodeGenTargetMachineImpl(T, computeDataLayout(TT, CPU, Options), TT, CPU,
                               FS, Options, getEffectiveRelocModel(RM),
                               getEffectiveCodeModel(CM, CodeModel::Small), OL),
      TLOF(std::make_unique<TargetLoweringObjectFileELF>()),
      Subtarget(TT, std::string(CPU), std::string(FS), *this) {
  initAsmInfo();
}

NDS32TargetMachine::~NDS32TargetMachine() = default;

namespace {
class NDS32PassConfig : public TargetPassConfig {
public:
  NDS32PassConfig(NDS32TargetMachine &TM, PassManagerBase &PM)
      : TargetPassConfig(TM, PM) {}

  NDS32TargetMachine &getNDS32TargetMachine() const {
    return getTM<NDS32TargetMachine>();
  }

  void addIRPasses() override {
    // Expand atomics to their non-atomic equivalents (this is a single-hart
    // target; see NDS32TargetLowering's shouldExpandAtomic* hooks).
    addPass(createAtomicExpandLegacyPass());
    TargetPassConfig::addIRPasses();
  }

  bool addInstSelector() override {
    addPass(createNDS32ISelDag(getNDS32TargetMachine(), getOptLevel()));
    return false;
  }

  void addPreEmitPass() override {
    // Compress eligible 32-bit instructions to 16-bit forms for code size.
    addPass(createNDS32CompressPass());
  }
};
} // namespace

TargetPassConfig *NDS32TargetMachine::createPassConfig(PassManagerBase &PM) {
  return new NDS32PassConfig(*this, PM);
}

MachineFunctionInfo *NDS32TargetMachine::createMachineFunctionInfo(
    BumpPtrAllocator &Allocator, const Function &F,
    const TargetSubtargetInfo *STI) const {
  return NDS32MachineFunctionInfo::create<NDS32MachineFunctionInfo>(Allocator, F,
                                                                    STI);
}
