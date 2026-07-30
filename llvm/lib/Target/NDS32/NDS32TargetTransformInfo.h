//===-- NDS32TargetTransformInfo.h - NDS32 specific TTI ---------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// NDS32 target-specific cost model. Its only job today is to let a target
// suppress IR-level constant lookup tables, which -nds32-no-jump-tables cannot
// reach: that flag raises the ISel jump-table threshold, but SimplifyCFG's
// switch-to-lookup-table transform runs long before ISel and asks TTI instead.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_NDS32_NDS32TARGETTRANSFORMINFO_H
#define LLVM_LIB_TARGET_NDS32_NDS32TARGETTRANSFORMINFO_H

#include "NDS32Subtarget.h"
#include "NDS32TargetMachine.h"
#include "llvm/CodeGen/BasicTTIImpl.h"

namespace llvm {

class NDS32TTIImpl final : public BasicTTIImplBase<NDS32TTIImpl> {
  using BaseT = BasicTTIImplBase<NDS32TTIImpl>;
  friend BaseT;

  const NDS32Subtarget *ST;
  const NDS32TargetLowering *TLI;

  const NDS32Subtarget *getST() const { return ST; }
  const NDS32TargetLowering *getTLI() const { return TLI; }

public:
  explicit NDS32TTIImpl(const NDS32TargetMachine *TM, const Function &F)
      : BaseT(TM, F.getDataLayout()), ST(TM->getSubtargetImpl(F)),
        TLI(ST->getTargetLowering()) {}

  /// Whether SimplifyCFG may turn a switch into a constant array indexed by the
  /// condition.
  ///
  /// Gated on the same flag as jump tables, because it is the same hazard: on a
  /// target that cannot read its own read-only data back faithfully, indexing a
  /// compiler-emitted table yields a corrupted value. For a jump table that is a
  /// branch to an arbitrary address; for a lookup table it is a silently wrong
  /// constant, which is harder to notice and just as wrong.
  bool shouldBuildLookupTables() const override;

  /// Relative lookup tables store 32-bit offsets rather than pointers. Same
  /// hazard, same gate.
  bool shouldBuildRelLookupTables() const override;
};

} // namespace llvm

#endif // LLVM_LIB_TARGET_NDS32_NDS32TARGETTRANSFORMINFO_H
