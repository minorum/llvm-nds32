//===-- NDS32Subtarget.h - Define Subtarget for the NDS32 -------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_NDS32_NDS32SUBTARGET_H
#define LLVM_LIB_TARGET_NDS32_NDS32SUBTARGET_H

#include "NDS32FrameLowering.h"
#include "NDS32ISelLowering.h"
#include "NDS32InstrInfo.h"
#include "NDS32RegisterInfo.h"
#include "llvm/CodeGen/SelectionDAGTargetInfo.h"
#include "llvm/CodeGen/TargetSubtargetInfo.h"
#include "llvm/IR/DataLayout.h"
#include <string>

#define GET_SUBTARGETINFO_HEADER
#include "NDS32GenSubtargetInfo.inc"

namespace llvm {
class StringRef;

class NDS32Subtarget : public NDS32GenSubtargetInfo {
  virtual void anchor();

  // ISA-version features, set from the CPU/feature string by the generated
  // ParseSubtargetFeatures (field names must match the SubtargetFeatures in
  // NDS32.td). V3 implies V2.
  bool HasV2Ops = false;
  bool HasV3Ops = false;
  // Single-precision hardware FPU (AndeStar V3f).
  bool HasFPU = false;
  // Hard-float ABI: pass/return single-precision floats in FP registers
  // (Andes 2fp+ ABI). Opt-in on top of the FPU ISA, mirroring GCC's separation
  // of -mext-fpu-sp (ISA) from -mfloat-abi=hard (ABI).
  bool HasHardFloatABI = false;
  // Core-configuration features (see NDS32.td): a reduced-register core has no
  // r11-r14/r16-r27, and HasNo16Bit suppresses the compressed forms.
  bool HasReducedRegs = false;
  bool HasNo16Bit = false;

  NDS32InstrInfo InstrInfo;
  NDS32TargetLowering TLInfo;
  SelectionDAGTargetInfo TSInfo;
  NDS32FrameLowering FrameLowering;

public:
  NDS32Subtarget(const Triple &TT, const std::string &CPU,
                 const std::string &FS, const TargetMachine &TM);

  NDS32Subtarget &initializeSubtargetDependencies(StringRef CPU, StringRef FS);

  void ParseSubtargetFeatures(StringRef CPU, StringRef TuneCPU, StringRef FS);

  // True when the (at least) V2 / V3 base ISA is available.
  bool hasV2Ops() const { return HasV2Ops; }
  bool hasV3Ops() const { return HasV3Ops; }
  bool hasFPU() const { return HasFPU; }
  bool hasHardFloatABI() const { return HasHardFloatABI; }
  bool hasReducedRegs() const { return HasReducedRegs; }
  // Note the inversion: the feature is opt-out ("no-16bit"), so the query is
  // "may I emit compressed forms?".
  bool has16Bit() const { return !HasNo16Bit; }

  const TargetFrameLowering *getFrameLowering() const override {
    return &FrameLowering;
  }
  const NDS32InstrInfo *getInstrInfo() const override { return &InstrInfo; }
  const NDS32RegisterInfo *getRegisterInfo() const override {
    return &getInstrInfo()->getRegisterInfo();
  }
  const NDS32TargetLowering *getTargetLowering() const override {
    return &TLInfo;
  }
  const SelectionDAGTargetInfo *getSelectionDAGInfo() const override {
    return &TSInfo;
  }
};
} // namespace llvm

#endif // LLVM_LIB_TARGET_NDS32_NDS32SUBTARGET_H
