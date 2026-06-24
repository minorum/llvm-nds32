//===-- NDS32InstPrinter.cpp - Convert NDS32 MCInst to asm syntax ---------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "NDS32InstPrinter.h"
#include "NDS32MCTargetDesc.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCRegister.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/FormattedStream.h"

using namespace llvm;

#define DEBUG_TYPE "asm-printer"

#define PRINT_ALIAS_INSTR
#include "NDS32GenAsmWriter.inc"

void NDS32InstPrinter::printRegName(raw_ostream &OS, MCRegister Reg) {
  OS << getRegisterName(Reg);
}

void NDS32InstPrinter::printInst(const MCInst *MI, uint64_t Address,
                                 StringRef Annot,
                                 const MCSubtargetInfo &STI,
                                 raw_ostream &OS) {
  if (!printAliasInstr(MI, Address, OS))
    printInstruction(MI, Address, OS);
  printAnnotation(OS, Annot);
}

void NDS32InstPrinter::printOperand(const MCInst *MI, unsigned OpNo,
                                    raw_ostream &OS, const char *Modifier) {
  assert((Modifier == nullptr || Modifier[0] == 0) &&
         "NDS32 does not currently support operand modifiers");

  const MCOperand &Op = MI->getOperand(OpNo);
  if (Op.isReg()) {
    OS << getRegisterName(Op.getReg());
    return;
  }
  if (Op.isImm()) {
    OS << formatImm(Op.getImm());
    return;
  }

  assert(Op.isExpr() && "unknown operand kind in NDS32InstPrinter");
  MAI.printExpr(OS, *Op.getExpr());
}

void NDS32InstPrinter::printMemOperand(const MCInst *MI, unsigned OpNo,
                                       raw_ostream &OS, const char *Modifier) {
  assert((Modifier == nullptr || Modifier[0] == 0) &&
         "NDS32 does not currently support memory operand modifiers");

  printOperand(MI, OpNo, OS);

  const MCOperand &Offset = MI->getOperand(OpNo + 1);
  if (Offset.isImm()) {
    int64_t Value = Offset.getImm();
    if (Value >= 0)
      OS << " + " << Value;
    else
      OS << " - " << -Value;
    return;
  }

  OS << " + ";
  printOperand(MI, OpNo + 1, OS);
}

void NDS32InstPrinter::printRegOffsetMem(const MCInst *MI, unsigned OpNo,
                                         raw_ostream &OS,
                                         const char *Modifier) {
  assert((Modifier == nullptr || Modifier[0] == 0) &&
         "NDS32 does not currently support memory operand modifiers");
  // base + (index << scale)
  printOperand(MI, OpNo, OS);
  OS << " + ";
  printOperand(MI, OpNo + 1, OS);
  int64_t Scale = MI->getOperand(OpNo + 2).getImm();
  if (Scale)
    OS << " << " << Scale;
}
