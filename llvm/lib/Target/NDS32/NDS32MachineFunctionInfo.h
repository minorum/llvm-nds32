//===-- NDS32MachineFunctionInfo.h - NDS32 per-function info ----*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_NDS32_NDS32MACHINEFUNCTIONINFO_H
#define LLVM_LIB_TARGET_NDS32_NDS32MACHINEFUNCTIONINFO_H

#include "llvm/CodeGen/MachineFunction.h"

namespace llvm {

// Per-function NDS32 state. Currently only tracks the variadic-argument save
// area so VASTART can hand out its address.
class NDS32MachineFunctionInfo : public MachineFunctionInfo {
  // Frame index of the first variadic (unnamed) argument.
  int VarArgsFrameIndex = 0;

public:
  NDS32MachineFunctionInfo() = default;
  NDS32MachineFunctionInfo(const Function &, const TargetSubtargetInfo *) {}

  int getVarArgsFrameIndex() const { return VarArgsFrameIndex; }
  void setVarArgsFrameIndex(int FI) { VarArgsFrameIndex = FI; }
};

} // namespace llvm

#endif // LLVM_LIB_TARGET_NDS32_NDS32MACHINEFUNCTIONINFO_H
