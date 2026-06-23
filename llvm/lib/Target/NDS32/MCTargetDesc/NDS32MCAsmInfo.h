//===-- NDS32MCAsmInfo.h - NDS32 asm properties -----------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_NDS32_MCTARGETDESC_NDS32MCASMINFO_H
#define LLVM_LIB_TARGET_NDS32_MCTARGETDESC_NDS32MCASMINFO_H

#include "llvm/MC/MCAsmInfoELF.h"
#include "llvm/MC/MCExpr.h"

namespace llvm {
class Triple;
class StringRef;

class NDS32MCAsmInfo : public MCAsmInfoELF {
  void anchor() override;

public:
  explicit NDS32MCAsmInfo(const Triple &TT);

  void printSpecifierExpr(raw_ostream &OS,
                          const MCSpecifierExpr &Expr) const override;
};

namespace NDS32 {
// Relocation specifiers (the LLVM 22 replacement for the old NDS32MCExpr
// VariantKind). Carried on MCSpecifierExpr and on the evaluated MCValue.
enum Specifier {
  S_None,
  S_HI20,    // hi20(sym)
  S_LO12S0,  // lo12(sym), byte-addressed
  S_LO12S2,  // lo12(sym), word-addressed (lwi/swi)
};

StringRef getSpecifierName(uint16_t S);
} // namespace NDS32

} // namespace llvm

#endif // LLVM_LIB_TARGET_NDS32_MCTARGETDESC_NDS32MCASMINFO_H
