//===-- NDS32TargetInfo.cpp - NDS32 Target Implementation -----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "TargetInfo/NDS32TargetInfo.h"
#include "llvm/MC/TargetRegistry.h"
using namespace llvm;

Target &llvm::getTheNDS32Target() {
  static Target TheNDS32Target;
  return TheNDS32Target;
}

Target &llvm::getTheNDS32leTarget() {
  static Target TheNDS32leTarget;
  return TheNDS32leTarget;
}

Target &llvm::getTheNDS32beTarget() {
  static Target TheNDS32beTarget;
  return TheNDS32beTarget;
}

extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeNDS32TargetInfo() {
  RegisterTarget<Triple::nds32, /*HasJIT=*/true> X(
      getTheNDS32Target(), "nds32", "Andes NDS32 (default/big-endian)", "NDS32");

  RegisterTarget<Triple::nds32le, /*HasJIT=*/true> Y(
      getTheNDS32leTarget(), "nds32le", "Andes NDS32 (little-endian)", "NDS32");

  RegisterTarget<Triple::nds32be, /*HasJIT=*/true> Z(
      getTheNDS32beTarget(), "nds32be", "Andes NDS32 (big-endian)", "NDS32");
}
