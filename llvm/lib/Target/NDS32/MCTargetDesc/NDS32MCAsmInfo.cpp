//===-- NDS32MCAsmInfo.cpp - NDS32 asm properties -------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "NDS32MCAsmInfo.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Support/raw_ostream.h"
using namespace llvm;

void NDS32MCAsmInfo::anchor() {}

NDS32MCAsmInfo::NDS32MCAsmInfo(const Triple &TT) {
  CodePointerSize = 4;
  CalleeSaveStackSlotSize = 4;

  CommentString = "!";
  AlignmentIsInBytes = false;
  UsesELFSectionDirectiveForBSS = true;
  SupportsDebugInformation = true;
}

void NDS32MCAsmInfo::printSpecifierExpr(raw_ostream &OS,
                                        const MCSpecifierExpr &Expr) const {
  StringRef S = NDS32::getSpecifierName(Expr.getSpecifier());
  if (!S.empty())
    OS << S << '(';
  printExpr(OS, *Expr.getSubExpr());
  if (!S.empty())
    OS << ')';
}

StringRef NDS32::getSpecifierName(uint16_t S) {
  switch (S) {
  case NDS32::S_None:
    return StringRef();
  case NDS32::S_HI20:
    return "hi20";
  case NDS32::S_LO12S0:
  case NDS32::S_LO12S2:
    return "lo12";
  case NDS32::S_GOTOFF_HI20:
    return "hi20gotoff";
  case NDS32::S_GOTOFF_LO12:
    return "lo12gotoff";
  case NDS32::S_GOT_HI20:
    return "hi20got";
  case NDS32::S_GOT_LO12:
    return "lo12got";
  case NDS32::S_TLS_LE_HI20:
    return "hi20tpoff";
  case NDS32::S_TLS_LE_LO12:
    return "lo12tpoff";
  default:
    llvm_unreachable("Invalid NDS32 specifier");
  }
}
