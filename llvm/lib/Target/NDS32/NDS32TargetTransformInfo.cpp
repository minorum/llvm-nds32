//===-- NDS32TargetTransformInfo.cpp - NDS32 specific TTI -----------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "NDS32TargetTransformInfo.h"

using namespace llvm;

#define DEBUG_TYPE "nds32tti"

// Defined in NDS32ISelLowering.cpp, where the jump-table half of the same
// hazard is handled and documented.
namespace llvm {
extern cl::opt<bool> NDS32NoJumpTables;
} // namespace llvm

bool NDS32TTIImpl::shouldBuildLookupTables() const {
  if (NDS32NoJumpTables)
    return false;
  return BaseT::shouldBuildLookupTables();
}

bool NDS32TTIImpl::shouldBuildRelLookupTables() const {
  if (NDS32NoJumpTables)
    return false;
  return BaseT::shouldBuildRelLookupTables();
}
