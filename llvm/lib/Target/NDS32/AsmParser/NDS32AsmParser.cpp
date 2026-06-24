//===-- NDS32AsmParser.cpp - Parse NDS32 assembly to MCInst --------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/NDS32MCTargetDesc.h"
#include "TargetInfo/NDS32TargetInfo.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCParser/AsmLexer.h"
#include "llvm/MC/MCParser/MCAsmParser.h"
#include "llvm/MC/MCParser/MCParsedAsmOperand.h"
#include "llvm/MC/MCParser/MCTargetAsmParser.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCStreamer.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/Casting.h"

using namespace llvm;

namespace {

// A parsed operand: a literal token, a register, or an immediate expression.
class NDS32Operand : public MCParsedAsmOperand {
  enum KindTy { Token, Register, Immediate, Memory, MemoryRR } Kind;
  SMLoc StartLoc, EndLoc;
  StringRef Tok;
  MCRegister Reg;
  const MCExpr *Imm = nullptr;
  // Memory: base + offset. MemoryRR: base + index << scale.
  MCRegister Base;
  MCRegister Index;
  const MCExpr *Off = nullptr;
  int64_t Scale = 0;

public:
  NDS32Operand(KindTy K) : Kind(K) {}

  bool isToken() const override { return Kind == Token; }
  bool isReg() const override { return Kind == Register; }
  bool isImm() const override { return Kind == Immediate; }
  bool isMem() const override { return Kind == Memory; }
  bool isMemRR() const { return Kind == MemoryRR; }

  StringRef getToken() const { return Tok; }
  MCRegister getReg() const override {
    assert(Kind == Register);
    return Reg;
  }
  const MCExpr *getImm() const {
    assert(Kind == Immediate);
    return Imm;
  }

  SMLoc getStartLoc() const override { return StartLoc; }
  SMLoc getEndLoc() const override { return EndLoc; }

  void addExpr(MCInst &Inst, const MCExpr *Expr) const {
    if (auto *CE = dyn_cast<MCConstantExpr>(Expr))
      Inst.addOperand(MCOperand::createImm(CE->getValue()));
    else
      Inst.addOperand(MCOperand::createExpr(Expr));
  }
  void addRegOperands(MCInst &Inst, unsigned N) const {
    assert(N == 1);
    Inst.addOperand(MCOperand::createReg(Reg));
  }
  void addImmOperands(MCInst &Inst, unsigned N) const {
    assert(N == 1);
    addExpr(Inst, Imm);
  }
  void addMemOperands(MCInst &Inst, unsigned N) const {
    assert(N == 2);
    Inst.addOperand(MCOperand::createReg(Base));
    addExpr(Inst, Off);
  }
  void addMemRROperands(MCInst &Inst, unsigned N) const {
    assert(N == 3);
    Inst.addOperand(MCOperand::createReg(Base));
    Inst.addOperand(MCOperand::createReg(Index));
    Inst.addOperand(MCOperand::createImm(Scale));
  }

  void print(raw_ostream &OS, const MCAsmInfo &MAI) const override {
    switch (Kind) {
    case Token: OS << "Token:" << Tok; break;
    case Register: OS << "Reg:" << Reg.id(); break;
    case Immediate: OS << "Imm"; break;
    }
  }

  static std::unique_ptr<NDS32Operand> createToken(StringRef Str, SMLoc S) {
    auto Op = std::make_unique<NDS32Operand>(Token);
    Op->Tok = Str;
    Op->StartLoc = Op->EndLoc = S;
    return Op;
  }
  static std::unique_ptr<NDS32Operand> createReg(MCRegister Reg, SMLoc S,
                                                 SMLoc E) {
    auto Op = std::make_unique<NDS32Operand>(Register);
    Op->Reg = Reg;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }
  static std::unique_ptr<NDS32Operand> createImm(const MCExpr *Val, SMLoc S,
                                                 SMLoc E) {
    auto Op = std::make_unique<NDS32Operand>(Immediate);
    Op->Imm = Val;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }
  static std::unique_ptr<NDS32Operand> createMem(MCRegister Base,
                                                 const MCExpr *Off, SMLoc S,
                                                 SMLoc E) {
    auto Op = std::make_unique<NDS32Operand>(Memory);
    Op->Base = Base;
    Op->Off = Off;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }
  static std::unique_ptr<NDS32Operand> createMemRR(MCRegister Base,
                                                   MCRegister Index,
                                                   int64_t Scale, SMLoc S,
                                                   SMLoc E) {
    auto Op = std::make_unique<NDS32Operand>(MemoryRR);
    Op->Base = Base;
    Op->Index = Index;
    Op->Scale = Scale;
    Op->StartLoc = S;
    Op->EndLoc = E;
    return Op;
  }
};

class NDS32AsmParser : public MCTargetAsmParser {
  MCAsmParser &Parser;

#define GET_ASSEMBLER_HEADER
#include "NDS32GenAsmMatcher.inc"

  bool parseOperand(OperandVector &Operands);
  MCRegister matchRegister(StringRef Name);

public:
  NDS32AsmParser(const MCSubtargetInfo &STI, MCAsmParser &P,
                 const MCInstrInfo &MII, const MCTargetOptions &Options)
      : MCTargetAsmParser(Options, STI, MII), Parser(P) {
    setAvailableFeatures(ComputeAvailableFeatures(STI.getFeatureBits()));
  }

  bool parseRegister(MCRegister &Reg, SMLoc &StartLoc, SMLoc &EndLoc) override;
  ParseStatus tryParseRegister(MCRegister &Reg, SMLoc &StartLoc,
                               SMLoc &EndLoc) override;
  bool parseInstruction(ParseInstructionInfo &Info, StringRef Name,
                        SMLoc NameLoc, OperandVector &Operands) override;
  bool matchAndEmitInstruction(SMLoc IDLoc, unsigned &Opcode,
                               OperandVector &Operands, MCStreamer &Out,
                               uint64_t &ErrorInfo,
                               bool MatchingInlineAsm) override;
};
} // namespace

#define GET_REGISTER_MATCHER
#define GET_MATCHER_IMPLEMENTATION
#include "NDS32GenAsmMatcher.inc"

MCRegister NDS32AsmParser::matchRegister(StringRef Name) {
  // Generated MatchRegisterName expects the bare name; our AsmNames include "$".
  MCRegister Reg = MatchRegisterName(Name);
  if (!Reg && Name.starts_with("$"))
    Reg = MatchRegisterName(Name.drop_front());
  return Reg;
}

bool NDS32AsmParser::parseRegister(MCRegister &Reg, SMLoc &StartLoc,
                                   SMLoc &EndLoc) {
  if (!tryParseRegister(Reg, StartLoc, EndLoc).isSuccess())
    return Error(StartLoc, "invalid register");
  return false;
}

ParseStatus NDS32AsmParser::tryParseRegister(MCRegister &Reg, SMLoc &StartLoc,
                                             SMLoc &EndLoc) {
  const AsmToken &Tok = Parser.getLexer().getTok();
  StartLoc = Tok.getLoc();
  EndLoc = Tok.getEndLoc();
  // A register is "$rN"/"$fsN": a '$' followed by an identifier.
  if (Tok.is(AsmToken::Dollar)) {
    const AsmToken &Next = Parser.getLexer().peekTok();
    Reg = matchRegister(("$" + Next.getString()).str());
    if (Reg) {
      Parser.getLexer().Lex();
      Parser.getLexer().Lex();
      return ParseStatus::Success;
    }
    return ParseStatus::NoMatch;
  }
  if (Tok.is(AsmToken::Identifier)) {
    Reg = matchRegister(Tok.getString());
    if (Reg) {
      Parser.getLexer().Lex();
      return ParseStatus::Success;
    }
  }
  return ParseStatus::NoMatch;
}

bool NDS32AsmParser::parseOperand(OperandVector &Operands) {
  AsmLexer &Lexer = Parser.getLexer();
  SMLoc S = Lexer.getTok().getLoc();

  // Bracketed memory: "[" $base ("]" | "+" off "]" | "+" $idx "<<" sv "]").
  // The brackets are emitted as literal tokens; the inner part is one Mem /
  // MemRR operand.
  if (Lexer.is(AsmToken::LBrac)) {
    Operands.push_back(NDS32Operand::createToken("[", S));
    Lexer.Lex();
    MCRegister Base;
    SMLoc BS, BE;
    if (!tryParseRegister(Base, BS, BE).isSuccess())
      return Error(Lexer.getTok().getLoc(), "expected base register");

    if (Lexer.is(AsmToken::Plus)) {
      Lexer.Lex();
      MCRegister Index;
      SMLoc IS, IE;
      if (tryParseRegister(Index, IS, IE).isSuccess()) {
        // Register-offset: "+ $index << scale".
        int64_t Scale = 0;
        if (Lexer.is(AsmToken::LessLess)) {
          Lexer.Lex();
          const MCExpr *SExpr;
          SMLoc SE;
          if (Parser.parseExpression(SExpr, SE))
            return true;
          if (auto *CE = dyn_cast<MCConstantExpr>(SExpr))
            Scale = CE->getValue();
          else
            return Error(SE, "expected constant scale");
        }
        Operands.push_back(
            NDS32Operand::createMemRR(Base, Index, Scale, S, IE));
      } else {
        const MCExpr *Off;
        SMLoc OE;
        if (Parser.parseExpression(Off, OE))
          return true;
        Operands.push_back(NDS32Operand::createMem(Base, Off, S, OE));
      }
    } else {
      const MCExpr *Zero = MCConstantExpr::create(0, Parser.getContext());
      Operands.push_back(NDS32Operand::createMem(Base, Zero, S, BE));
    }

    if (Lexer.isNot(AsmToken::RBrac))
      return Error(Lexer.getTok().getLoc(), "expected ']'");
    Operands.push_back(NDS32Operand::createToken("]", Lexer.getTok().getLoc()));
    Lexer.Lex();
    return false;
  }

  // Register?
  MCRegister Reg;
  SMLoc RS, RE;
  if (tryParseRegister(Reg, RS, RE).isSuccess()) {
    Operands.push_back(NDS32Operand::createReg(Reg, RS, RE));
    return false;
  }

  // Otherwise an immediate/expression.
  const MCExpr *Expr;
  SMLoc E;
  if (Parser.parseExpression(Expr, E))
    return true;
  Operands.push_back(NDS32Operand::createImm(Expr, S, E));
  return false;
}

bool NDS32AsmParser::parseInstruction(ParseInstructionInfo &Info,
                                      StringRef Name, SMLoc NameLoc,
                                      OperandVector &Operands) {
  Operands.push_back(NDS32Operand::createToken(Name, NameLoc));
  if (Parser.getLexer().is(AsmToken::EndOfStatement))
    return false;

  if (parseOperand(Operands))
    return true;
  while (Parser.getLexer().is(AsmToken::Comma)) {
    Parser.getLexer().Lex();
    if (parseOperand(Operands))
      return true;
  }
  if (Parser.getLexer().isNot(AsmToken::EndOfStatement))
    return Error(Parser.getLexer().getTok().getLoc(), "unexpected token");
  Parser.Lex();
  return false;
}

bool NDS32AsmParser::matchAndEmitInstruction(SMLoc IDLoc, unsigned &Opcode,
                                             OperandVector &Operands,
                                             MCStreamer &Out,
                                             uint64_t &ErrorInfo,
                                             bool MatchingInlineAsm) {
  MCInst Inst;
  unsigned Result =
      MatchInstructionImpl(Operands, Inst, ErrorInfo, MatchingInlineAsm);
  switch (Result) {
  case Match_Success:
    Inst.setLoc(IDLoc);
    Out.emitInstruction(Inst, getSTI());
    return false;
  case Match_MnemonicFail:
    return Error(IDLoc, "unrecognized instruction mnemonic");
  case Match_InvalidOperand:
    return Error(IDLoc, "invalid operand for instruction");
  default:
    return Error(IDLoc, "failed to match instruction");
  }
}

extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeNDS32AsmParser() {
  RegisterMCAsmParser<NDS32AsmParser> X(getTheNDS32Target());
  RegisterMCAsmParser<NDS32AsmParser> Y(getTheNDS32leTarget());
  RegisterMCAsmParser<NDS32AsmParser> Z(getTheNDS32beTarget());
}
