//===-- NDS32.h - Top-level interface for NDS32 representation -*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_NDS32_NDS32_H
#define LLVM_LIB_TARGET_NDS32_NDS32_H

#include "MCTargetDesc/NDS32MCTargetDesc.h"
#include "llvm/Target/TargetMachine.h"

namespace llvm {
class FunctionPass;
class NDS32TargetMachine;
class PassRegistry;

FunctionPass *createNDS32ISelDag(NDS32TargetMachine &TM,
                                 CodeGenOptLevel OptLevel);

FunctionPass *createNDS32CompressPass();

} // namespace llvm

#endif // LLVM_LIB_TARGET_NDS32_NDS32_H
