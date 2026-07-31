//===-- NDS32AsmParser.cpp - Parse NDS32 assembly to MCInst --------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/NDS32MCAsmInfo.h"
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
#include "llvm/ADT/StringSwitch.h"
#include <optional>
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/ADT/StringSwitch.h"
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

  // How an instruction spells the inside of its brackets. The AsmStrings differ
  // and the matcher is unforgiving, so the parser has to know which shape to
  // build before it has seen the operands.
  enum class Brackets {
    Memory,     // "[$ra + off]" as ONE memory operand (the 32-bit memri forms)
    BareReg,    // "[$ra]"       -- post-increment, load/store-multiple, *450
    RegPlusImm, // "[$ra + imm]" as TWO operands (the 16-bit *333 forms)
  };
  static Brackets bracketsFor(StringRef Mnemonic);
  bool parseOperand(OperandVector &Operands, Brackets Shape);
  /// Parse a relocation specifier such as `hi20(sym)` or `lo12(sym)` into an
  /// MCSpecifierExpr. Returns false if the lexer is not looking at one.
  bool parseSpecifierExpr(const MCExpr *&Res, SMLoc &EndLoc);
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
  // Accept the ABI spellings as input too (the printer emits them).
  if (!Reg) {
    StringRef N = Name.starts_with("$") ? Name.drop_front() : Name;
    Reg = StringSwitch<MCRegister>(N)
              .Case("fp", NDS32::R28)
              .Case("gp", NDS32::R29)
              .Case("lp", NDS32::R30)
              .Case("sp", NDS32::R31)
              .Default(MCRegister());
  }
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

/// The relocation specifiers this target spells as `name(expr)`.
///
/// Codegen has always been able to emit these fixups; only hand-written
/// assembly could not ask for them, which meant a `.S` file (or an `asm!`
/// block) had no way to reference a symbol's address at all. `lo12` maps to two
/// different fixups depending on whether the instruction's immediate is byte-
/// or word-scaled, so the choice is made after the mnemonic is known — see
/// the S_LO12S2 fixup below.
static std::optional<NDS32::Specifier> specifierForName(StringRef Name) {
  return StringSwitch<std::optional<NDS32::Specifier>>(Name)
      .Case("hi20", NDS32::S_HI20)
      .Case("lo12", NDS32::S_LO12S0)
      .Case("hi20gotoff", NDS32::S_GOTOFF_HI20)
      .Case("lo12gotoff", NDS32::S_GOTOFF_LO12)
      .Case("hi20got", NDS32::S_GOT_HI20)
      .Case("lo12got", NDS32::S_GOT_LO12)
      .Case("hi20tpoff", NDS32::S_TLS_LE_HI20)
      .Case("lo12tpoff", NDS32::S_TLS_LE_LO12)
      .Default(std::nullopt);
}

bool NDS32AsmParser::parseSpecifierExpr(const MCExpr *&Res, SMLoc &EndLoc) {
  AsmLexer &Lexer = Parser.getLexer();
  if (Lexer.isNot(AsmToken::Identifier))
    return false;
  auto Spec = specifierForName(Lexer.getTok().getIdentifier());
  if (!Spec)
    return false;
  // Only treat it as a specifier when a '(' follows; a bare symbol that happens
  // to be called `hi20` is still a symbol.
  if (Lexer.peekTok().isNot(AsmToken::LParen))
    return false;

  Lexer.Lex(); // name
  Lexer.Lex(); // '('
  const MCExpr *Sub;
  if (Parser.parseExpression(Sub, EndLoc))
    return true;
  if (Lexer.isNot(AsmToken::RParen)) {
    Error(Lexer.getTok().getLoc(), "expected ')' closing relocation specifier");
    return true;
  }
  EndLoc = Lexer.getTok().getEndLoc();
  Lexer.Lex(); // ')'
  Res = MCSpecifierExpr::create(Sub, *Spec, Parser.getContext());
  return false;
}

NDS32AsmParser::Brackets NDS32AsmParser::bracketsFor(StringRef Name) {
  // A bare base register in brackets: post-increment loads/stores, every
  // load/store-multiple, and the 16-bit "450" forms. This has to be tested
  // FIRST -- `lwi333.bi` is spelled "[$ra], $imm", with the displacement after
  // the bracket, so the "333" rule below would put it in the wrong shape.
  if (Name.ends_with(".bi") || Name.ends_with("450") || Name.starts_with("lmw.") ||
      Name.starts_with("smw."))
    return Brackets::BareReg;
  // The 16-bit "333" forms name their base and displacement separately.
  if (Name.ends_with("333"))
    return Brackets::RegPlusImm;
  return Brackets::Memory;
}

bool NDS32AsmParser::parseOperand(OperandVector &Operands, Brackets Shape) {
  AsmLexer &Lexer = Parser.getLexer();
  SMLoc S = Lexer.getTok().getLoc();

  // Bracketed memory: "[" $base ("]" | "+" off "]" | "+" $idx "<<" sv "]").
  // The brackets are emitted as literal tokens; the inner part is one Mem /
  // MemRR operand.
  if (Lexer.is(AsmToken::LBrac)) {
    Operands.push_back(NDS32Operand::createToken("[", S));
    Lexer.Lex();

    // Implicit-base form "[+ off]", used by the gp-, sp- and fp-relative loads
    // and stores whose base is fixed by the opcode. Their AsmStrings spell it
    // exactly this way, so without this the disassembler prints syntax the
    // assembler rejects -- `lwi.gp $r0, [+ -4]` round-tripped to
    // "error: expected base register".
    if (Lexer.is(AsmToken::Plus)) {
      Operands.push_back(
          NDS32Operand::createToken("+", Lexer.getTok().getLoc()));
      Lexer.Lex();
      const MCExpr *Off = nullptr;
      SMLoc OE;
      if (parseSpecifierExpr(Off, OE))
        return true;
      if (!Off && Parser.parseExpression(Off, OE))
        return true;
      Operands.push_back(NDS32Operand::createImm(Off, S, OE));
      if (Lexer.isNot(AsmToken::RBrac))
        return Error(Lexer.getTok().getLoc(), "expected ']'");
      Operands.push_back(
          NDS32Operand::createToken("]", Lexer.getTok().getLoc()));
      Lexer.Lex();
      return false;
    }

    MCRegister Base;
    SMLoc BS, BE;
    if (!tryParseRegister(Base, BS, BE).isSuccess())
      return Error(Lexer.getTok().getLoc(), "expected base register");

    // "[$ra + imm]" spelled as two operands rather than one memory operand.
    if (Shape == Brackets::RegPlusImm) {
      Operands.push_back(NDS32Operand::createReg(Base, BS, BE));
      if (Lexer.isNot(AsmToken::Plus))
        return Error(Lexer.getTok().getLoc(), "expected '+'");
      Operands.push_back(
          NDS32Operand::createToken("+", Lexer.getTok().getLoc()));
      Lexer.Lex();
      const MCExpr *Off = nullptr;
      SMLoc OE;
      if (Parser.parseExpression(Off, OE))
        return true;
      Operands.push_back(NDS32Operand::createImm(Off, S, OE));
      if (Lexer.isNot(AsmToken::RBrac))
        return Error(Lexer.getTok().getLoc(), "expected ']'");
      Operands.push_back(
          NDS32Operand::createToken("]", Lexer.getTok().getLoc()));
      Lexer.Lex();
      return false;
    }

    // Bare base register in brackets; anything that follows (a post-increment
    // step, the register range of an LSMW) comes after the closing bracket as
    // its own operand.
    if (Shape == Brackets::BareReg) {
      if (Lexer.isNot(AsmToken::RBrac))
        return Error(Lexer.getTok().getLoc(), "expected ']'");
      Operands.push_back(NDS32Operand::createReg(Base, BS, BE));
      Operands.push_back(
          NDS32Operand::createToken("]", Lexer.getTok().getLoc()));
      Lexer.Lex();
      return false;
    }

    // A negative displacement is printed as "[$ra - 4]", so it arrives as a
    // Minus token rather than as part of the expression. Without this the
    // disassembler's own output for every negative offset -- 13 of them in the
    // firmware -- came back "expected base register".
    if (Lexer.is(AsmToken::Minus)) {
      Lexer.Lex();
      const MCExpr *Off = nullptr;
      SMLoc OE;
      if (Parser.parseExpression(Off, OE))
        return true;
      // Fold rather than wrap: the offset encoders read a constant out of the
      // operand, and handing them an MCUnaryExpr made them encode 0 for a
      // word offset and crash outright on a byte one.
      if (auto *CE = dyn_cast<MCConstantExpr>(Off))
        Off = MCConstantExpr::create(-CE->getValue(), Parser.getContext());
      else
        Off = MCUnaryExpr::createMinus(Off, Parser.getContext());
      Operands.push_back(NDS32Operand::createMem(Base, Off, S, OE));
      if (Lexer.isNot(AsmToken::RBrac))
        return Error(Lexer.getTok().getLoc(), "expected ']'");
      Operands.push_back(
          NDS32Operand::createToken("]", Lexer.getTok().getLoc()));
      Lexer.Lex();
      return false;
    }

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
        const MCExpr *Off = nullptr;
        SMLoc OE;
        if (parseSpecifierExpr(Off, OE))
          return true;
        if (!Off && Parser.parseExpression(Off, OE))
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

  // Otherwise a relocation specifier, or a plain immediate/expression.
  const MCExpr *Expr = nullptr;
  SMLoc E;
  if (parseSpecifierExpr(Expr, E))
    return true;
  if (!Expr && Parser.parseExpression(Expr, E))
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

  // Only ".bi" used to be recognised here, which covered lmw.bi and smw.bi but
  // missed the four base-updating multiples -- so `smw.adm` and `lmw.bim`, the
  // two commonest prologue/epilogue instructions in this firmware (123 and 125
  // uses), could not be assembled at all while their siblings could. The 16-bit
  // *333 and *450 forms were unreachable for the same reason.
  const Brackets Shape = bracketsFor(Name);

  if (parseOperand(Operands, Shape))
    return true;
  while (Parser.getLexer().is(AsmToken::Comma)) {
    Parser.getLexer().Lex();
    if (parseOperand(Operands, Shape))
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
