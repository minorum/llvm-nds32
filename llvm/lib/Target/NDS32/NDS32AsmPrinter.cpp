//===-- NDS32AsmPrinter.cpp - NDS32 LLVM assembly writer ------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "NDS32.h"
#include "NDS32InstrInfo.h"
#include "NDS32TargetMachine.h"
#include "TargetInfo/NDS32TargetInfo.h"
#include "MCTargetDesc/NDS32InstPrinter.h"
#include "MCTargetDesc/NDS32MCAsmInfo.h"
#include "llvm/CodeGen/AsmPrinter.h"
#include "llvm/CodeGen/MachineConstantPool.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineInstr.h"
#include "llvm/CodeGen/MachineModuleInfo.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCStreamer.h"
#include "llvm/MC/MCSymbol.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

#define DEBUG_TYPE "asm-printer"

namespace {
class NDS32AsmPrinter : public AsmPrinter {
public:
  NDS32AsmPrinter(TargetMachine &TM, std::unique_ptr<MCStreamer> Streamer)
      : AsmPrinter(TM, std::move(Streamer)) {}

  StringRef getPassName() const override { return "NDS32 Assembly Printer"; }

  void emitInstruction(const MachineInstr *MI) override;

  bool PrintAsmOperand(const MachineInstr *MI, unsigned OpNo,
                       const char *ExtraCode, raw_ostream &OS) override;
  bool PrintAsmMemoryOperand(const MachineInstr *MI, unsigned OpNo,
                             const char *ExtraCode, raw_ostream &OS) override;
};
} // end of anonymous namespace

// Print an inline-asm operand ($N substitution). Handles plain registers,
// immediates, and global addresses; defers modifiers (e.g. %c, %n) to the
// generic AsmPrinter implementation.
bool NDS32AsmPrinter::PrintAsmOperand(const MachineInstr *MI, unsigned OpNo,
                                      const char *ExtraCode, raw_ostream &OS) {
  if (ExtraCode && ExtraCode[0])
    return AsmPrinter::PrintAsmOperand(MI, OpNo, ExtraCode, OS);

  const MachineOperand &MO = MI->getOperand(OpNo);
  switch (MO.getType()) {
  case MachineOperand::MO_Register:
    OS << NDS32InstPrinter::getRegisterName(MO.getReg());
    return false;
  case MachineOperand::MO_Immediate:
    OS << MO.getImm();
    return false;
  case MachineOperand::MO_GlobalAddress:
    PrintSymbolOperand(MO, OS);
    return false;
  default:
    return AsmPrinter::PrintAsmOperand(MI, OpNo, ExtraCode, OS);
  }
}

// Print an inline-asm "m" memory operand as "[$base + off]" (the NDS32
// addressing syntax). The operand is a base register followed by an immediate
// offset, as produced by SelectInlineAsmMemoryOperand.
bool NDS32AsmPrinter::PrintAsmMemoryOperand(const MachineInstr *MI,
                                            unsigned OpNo, const char *ExtraCode,
                                            raw_ostream &OS) {
  if (ExtraCode && ExtraCode[0])
    return true; // unsupported modifier

  const MachineOperand &Base = MI->getOperand(OpNo);
  if (!Base.isReg())
    return true;

  OS << "[" << NDS32InstPrinter::getRegisterName(Base.getReg());
  const MachineOperand &Off = MI->getOperand(OpNo + 1);
  if (Off.isImm() && Off.getImm() != 0) {
    if (Off.getImm() > 0)
      OS << " + " << Off.getImm();
    else
      OS << " - " << -Off.getImm();
  }
  OS << "]";
  return false;
}

void NDS32AsmPrinter::emitInstruction(const MachineInstr *MI) {
  if (MI->isPseudo())
    return;

  MCInst TmpInst;
  TmpInst.setOpcode(MI->getOpcode());

  for (unsigned i = 0, e = MI->getNumOperands(); i != e; ++i) {
    const MachineOperand &MO = MI->getOperand(i);
    if (MO.isReg()) {
      TmpInst.addOperand(MCOperand::createReg(MO.getReg()));
    } else if (MO.isImm()) {
      TmpInst.addOperand(MCOperand::createImm(MO.getImm()));
    } else if (MO.isMBB()) {
      const MCExpr *Expr =
          MCSymbolRefExpr::create(MO.getMBB()->getSymbol(), OutContext);
      TmpInst.addOperand(MCOperand::createExpr(Expr));
    } else if (MO.isGlobal() || MO.isSymbol() || MO.isCPI() || MO.isJTI()) {
      MCSymbol *Sym;
      if (MO.isGlobal())
        Sym = getSymbol(MO.getGlobal());
      else if (MO.isSymbol())
        Sym = GetExternalSymbolSymbol(MO.getSymbolName());
      else if (MO.isCPI())
        Sym = GetCPISymbol(MO.getIndex());
      else
        Sym = GetJTISymbol(MO.getIndex());
      const MCExpr *Expr = MCSymbolRefExpr::create(Sym, OutContext);
      // Jump-table operands have no offset accessor; the others do.
      if (!MO.isJTI() && MO.getOffset())
        Expr = MCBinaryExpr::createAdd(
            Expr, MCConstantExpr::create(MO.getOffset(), OutContext),
            OutContext);

      NDS32::Specifier Spec;
      switch (MO.getTargetFlags()) {
      case NDS32II::MO_HI20:
        Spec = NDS32::S_HI20;
        break;
      case NDS32II::MO_LO12S0:
        Spec = NDS32::S_LO12S0;
        break;
      case NDS32II::MO_LO12S2:
        Spec = NDS32::S_LO12S2;
        break;
      case NDS32II::MO_GOTOFF_HI20:
        Spec = NDS32::S_GOTOFF_HI20;
        break;
      case NDS32II::MO_GOTOFF_LO12:
        Spec = NDS32::S_GOTOFF_LO12;
        break;
      case NDS32II::MO_GOT_HI20:
        Spec = NDS32::S_GOT_HI20;
        break;
      case NDS32II::MO_GOT_LO12:
        Spec = NDS32::S_GOT_LO12;
        break;
      case NDS32II::MO_TLS_LE_HI20:
        Spec = NDS32::S_TLS_LE_HI20;
        break;
      case NDS32II::MO_TLS_LE_LO12:
        Spec = NDS32::S_TLS_LE_LO12;
        break;
      default:
        Spec = NDS32::S_None;
        break;
      }
      if (Spec != NDS32::S_None) {
        Expr = MCSpecifierExpr::create(Expr, Spec, OutContext);
      }
      TmpInst.addOperand(MCOperand::createExpr(Expr));
    }
  }

  EmitToStreamer(*OutStreamer, TmpInst);
}

// Force static initialization.
extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeNDS32AsmPrinter() {
  RegisterAsmPrinter<NDS32AsmPrinter> X(getTheNDS32Target());
  RegisterAsmPrinter<NDS32AsmPrinter> Y(getTheNDS32leTarget());
  RegisterAsmPrinter<NDS32AsmPrinter> Z(getTheNDS32beTarget());
}
