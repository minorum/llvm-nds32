//===-- NDS32TargetMachine.cpp - Define TargetMachine for NDS32 -----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "NDS32TargetMachine.h"
#include "NDS32TargetTransformInfo.h"
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

namespace {
// Emit PIC jump tables into the function's own .text section. The default ELF
// behavior puts them in .rodata and assumes a relative *data* relocation exists
// for the EK_LabelDifference32 entries (LBB - LJTI). NDS32 has no 32-bit
// PC-relative data relocation, so that cross-section difference would be
// emitted as the (wrong) R_NDS32_25_PCREL branch relocation, corrupting the
// table. Keeping the table in .text makes LBB - LJTI an intra-section
// difference that folds to an assembly-time constant — matching the
// `base + entry` runtime computation, no relocation needed.
class NDS32ELFTargetObjectFile : public TargetLoweringObjectFileELF {
public:
  bool shouldPutJumpTableInFunctionSection(bool UsesLabelDifference,
                                           const Function &F) const override {
    // Only the label-difference (PIC) tables must live in .text; absolute
    // (non-PIC) tables relocate fine from .rodata.
    return UsesLabelDifference;
  }
};
} // namespace

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
      TLOF(std::make_unique<NDS32ELFTargetObjectFile>()),
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

TargetTransformInfo
NDS32TargetMachine::getTargetTransformInfo(const Function &F) const {
  return TargetTransformInfo(std::make_unique<NDS32TTIImpl>(this, F));
}
