//===-- NDS32MCCodeEmitter.cpp - Convert NDS32 to machine code ------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/NDS32MCTargetDesc.h"
#include "MCTargetDesc/NDS32MCAsmInfo.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/MC/MCCodeEmitter.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCExpr.h"
#include "llvm/MC/MCFixup.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/Support/Casting.h"
#include "llvm/Support/EndianStream.h"
#include "llvm/Support/ErrorHandling.h"
#include "llvm/Support/raw_ostream.h"

using namespace llvm;

namespace {
class NDS32MCCodeEmitter : public MCCodeEmitter {
  const MCRegisterInfo &MRI;
  bool IsLittleEndian;

public:
  NDS32MCCodeEmitter(const MCRegisterInfo &MRI, bool IsLittleEndian)
      : MRI(MRI), IsLittleEndian(IsLittleEndian) {}

  void encodeInstruction(const MCInst &MI, SmallVectorImpl<char> &CB,
                         SmallVectorImpl<MCFixup> &Fixups,
                         const MCSubtargetInfo &STI) const override;

private:
  uint32_t getReg(const MCOperand &Op) const;
  uint32_t getImm16(const MCInst &MI, const MCOperand &Op,
                    SmallVectorImpl<MCFixup> &Fixups,
                    const MCSubtargetInfo &STI) const;
  uint32_t getImm20(const MCInst &MI, const MCOperand &Op,
                    SmallVectorImpl<MCFixup> &Fixups,
                    const MCSubtargetInfo &STI) const;
  uint32_t getMemOffsetWords(const MCInst &MI, const MCOperand &Op,
                             SmallVectorImpl<MCFixup> &Fixups,
                             const MCSubtargetInfo &STI) const;
  uint32_t getMemOffsetBytes(const MCOperand &Op) const;
  uint32_t getMemOffsetHalfwords(const MCOperand &Op) const;
  uint32_t encodeBranchTarget(const MCOperand &Op, SmallVectorImpl<MCFixup> &Fixups,
                              MCFixupKind Kind) const;
};
} // namespace

uint32_t NDS32MCCodeEmitter::getReg(const MCOperand &Op) const {
  assert(Op.isReg() && "expected register operand");
  return MRI.getEncodingValue(Op.getReg());
}

uint32_t NDS32MCCodeEmitter::getImm16(const MCInst &MI, const MCOperand &Op,
                                      SmallVectorImpl<MCFixup> &Fixups,
                                      const MCSubtargetInfo &STI) const {
  if (Op.isImm())
    return static_cast<uint32_t>(Op.getImm()) & 0xffff;

  assert(Op.isExpr() && "expected immediate or expression operand");
  MCFixupKind Kind = MCFixupKind(0);
  if (const auto *SE = dyn_cast<MCSpecifierExpr>(Op.getExpr())) {
    switch (SE->getSpecifier()) {
    case NDS32::S_HI20:
      Kind = static_cast<MCFixupKind>(NDS32::fixup_nds32_hi20);
      break;
    case NDS32::S_LO12S0:
      Kind = static_cast<MCFixupKind>(NDS32::fixup_nds32_lo12s0);
      break;
    case NDS32::S_LO12S2:
      Kind = static_cast<MCFixupKind>(NDS32::fixup_nds32_lo12s2);
      break;
    default:
      llvm_unreachable("unsupported NDS32 specifier");
    }
  }
  if (Kind != 0) {
    Fixups.push_back(MCFixup::create(0, Op.getExpr(), Kind));
  }
  return 0;
}

uint32_t NDS32MCCodeEmitter::getImm20(const MCInst &MI, const MCOperand &Op,
                                      SmallVectorImpl<MCFixup> &Fixups,
                                      const MCSubtargetInfo &STI) const {
  if (Op.isImm())
    return static_cast<uint32_t>(Op.getImm()) & 0xfffff;

  assert(Op.isExpr() && "expected immediate or expression operand");
  MCFixupKind Kind = MCFixupKind(0);
  if (const auto *SE = dyn_cast<MCSpecifierExpr>(Op.getExpr())) {
    if (SE->getSpecifier() == NDS32::S_HI20)
      Kind = static_cast<MCFixupKind>(NDS32::fixup_nds32_hi20);
  }
  if (Kind != 0) {
    Fixups.push_back(MCFixup::create(0, Op.getExpr(), Kind));
  }
  return 0;
}

uint32_t NDS32MCCodeEmitter::getMemOffsetWords(const MCInst &MI, const MCOperand &Op,
                                               SmallVectorImpl<MCFixup> &Fixups,
                                               const MCSubtargetInfo &STI) const {
  if (Op.isImm()) {
    int64_t Offset = Op.getImm();
    if (Offset % 4 != 0)
      report_fatal_error("NDS32 lwi/swi offset must be word aligned");
    return static_cast<uint32_t>(Offset / 4) & 0x7fff;
  }

  assert(Op.isExpr() && "expected immediate or expression operand");
  MCFixupKind Kind = MCFixupKind(0);
  if (const auto *SE = dyn_cast<MCSpecifierExpr>(Op.getExpr())) {
    if (SE->getSpecifier() == NDS32::S_LO12S2)
      Kind = static_cast<MCFixupKind>(NDS32::fixup_nds32_lo12s2);
  }
  if (Kind != 0) {
    Fixups.push_back(MCFixup::create(0, Op.getExpr(), Kind));
  }
  return 0;
}

uint32_t NDS32MCCodeEmitter::getMemOffsetBytes(const MCOperand &Op) const {
  if (!Op.isImm())
    report_fatal_error("NDS32 byte memory offset must be an immediate");
  return static_cast<uint32_t>(Op.getImm()) & 0x7fff;
}

uint32_t NDS32MCCodeEmitter::getMemOffsetHalfwords(const MCOperand &Op) const {
  if (!Op.isImm())
    report_fatal_error("NDS32 halfword memory offset must be an immediate");
  int64_t Offset = Op.getImm();
  if (Offset % 2 != 0)
    report_fatal_error("NDS32 lhi/lhsi/shi offset must be halfword aligned");
  return static_cast<uint32_t>(Offset / 2) & 0x7fff;
}

uint32_t NDS32MCCodeEmitter::encodeBranchTarget(
    const MCOperand &Op, SmallVectorImpl<MCFixup> &Fixups,
    MCFixupKind Kind) const {
  if (Op.isImm())
    return static_cast<uint32_t>(Op.getImm() / 2);

  assert(Op.isExpr() && "expected branch target expression");
  // Branch fixups are PC-relative; in LLVM 22 this is carried per-fixup so the
  // MC layer computes the displacement relative to the fixup location.
  Fixups.push_back(MCFixup::create(0, Op.getExpr(), Kind, /*PCRel=*/true));
  return 0;
}

void NDS32MCCodeEmitter::encodeInstruction(
    const MCInst &MI, SmallVectorImpl<char> &CB, SmallVectorImpl<MCFixup> &Fixups,
    const MCSubtargetInfo &STI) const {
  uint32_t Bits = 0;

  switch (MI.getOpcode()) {
  case NDS32::NOP:
    Bits = 0x40000009;
    break;
  case NDS32::RET:
    Bits = 0x4a007820;
    break;
  case NDS32::MOVI:
    // movi takes a signed 20-bit immediate (field [19:0]).
    Bits = 0x44000000 | (getReg(MI.getOperand(0)) << 20) |
           getImm20(MI, MI.getOperand(1), Fixups, STI);
    break;
  case NDS32::SETHI:
    Bits = 0x46000000 | (getReg(MI.getOperand(0)) << 20) |
           getImm20(MI, MI.getOperand(1), Fixups, STI);
    break;
  case NDS32::ADDrr:
    Bits = 0x40000000 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           (getReg(MI.getOperand(2)) << 10);
    break;
  case NDS32::ADDri:
    Bits = 0x50000000 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           getImm16(MI, MI.getOperand(2), Fixups, STI);
    break;
  case NDS32::LWI:
    Bits = 0x04000000 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           getMemOffsetWords(MI, MI.getOperand(2), Fixups, STI);
    break;
  case NDS32::LBI:
    Bits = 0x00000000 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           getMemOffsetBytes(MI.getOperand(2));
    break;
  case NDS32::LBSI:
    Bits = 0x20000000 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           getMemOffsetBytes(MI.getOperand(2));
    break;
  case NDS32::LHI:
    Bits = 0x02000000 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           getMemOffsetHalfwords(MI.getOperand(2));
    break;
  case NDS32::LHSI:
    Bits = 0x22000000 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           getMemOffsetHalfwords(MI.getOperand(2));
    break;
  case NDS32::SWI:
    Bits = 0x14000000 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           getMemOffsetWords(MI, MI.getOperand(2), Fixups, STI);
    break;
  case NDS32::SBI:
    Bits = 0x10000000 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           getMemOffsetBytes(MI.getOperand(2));
    break;
  case NDS32::SHI:
    Bits = 0x12000000 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           getMemOffsetHalfwords(MI.getOperand(2));
    break;
  case NDS32::BR:
    Bits = 0x48000000 |
           encodeBranchTarget(MI.getOperand(0), Fixups,
                              static_cast<MCFixupKind>(NDS32::fixup_nds32_25_pcrel));
    break;
  case NDS32::JAL:
    Bits = 0x49000000 |
           encodeBranchTarget(MI.getOperand(0), Fixups,
                              static_cast<MCFixupKind>(NDS32::fixup_nds32_25_pcrel));
    break;
  case NDS32::JRAL:
    Bits = 0x4be00001 | (getReg(MI.getOperand(0)) << 10);
    break;
  case NDS32::JR:
    Bits = 0x4a000000 | (getReg(MI.getOperand(0)) << 10);
    break;
  case NDS32::SEB:
    Bits = 0x40008010 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15);
    break;
  case NDS32::SEH:
    Bits = 0x40008011 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15);
    break;
  case NDS32::ZEH:
    Bits = 0x40008013 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15);
    break;
  case NDS32::BEQZ:
    Bits = 0x4e020000 | (getReg(MI.getOperand(0)) << 20) |
           encodeBranchTarget(MI.getOperand(1), Fixups,
                              static_cast<MCFixupKind>(NDS32::fixup_nds32_17_pcrel));
    break;
  case NDS32::BNEZ:
    Bits = 0x4e030000 | (getReg(MI.getOperand(0)) << 20) |
           encodeBranchTarget(MI.getOperand(1), Fixups,
                              static_cast<MCFixupKind>(NDS32::fixup_nds32_17_pcrel));
    break;
  case NDS32::BEQ:
    Bits = 0x4c008000 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           encodeBranchTarget(MI.getOperand(2), Fixups,
                              static_cast<MCFixupKind>(NDS32::fixup_nds32_15_pcrel));
    break;
  case NDS32::BNE:
    Bits = 0x4c00c000 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           encodeBranchTarget(MI.getOperand(2), Fixups,
                              static_cast<MCFixupKind>(NDS32::fixup_nds32_15_pcrel));
    break;
  case NDS32::SUBrr:
    Bits = 0x40000001 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           (getReg(MI.getOperand(2)) << 10);
    break;
  case NDS32::MULrr:
    Bits = 0x42000024 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           (getReg(MI.getOperand(2)) << 10);
    break;
  case NDS32::DIVSR:
    Bits = 0x40000016 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(2)) << 15) |
           (getReg(MI.getOperand(3)) << 10) |
           (getReg(MI.getOperand(1)) << 5);
    break;
  case NDS32::DIVR:
    Bits = 0x40000017 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(2)) << 15) |
           (getReg(MI.getOperand(3)) << 10) |
           (getReg(MI.getOperand(1)) << 5);
    break;
  case NDS32::ANDrr:
    Bits = 0x40000002 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           (getReg(MI.getOperand(2)) << 10);
    break;
  case NDS32::ORrr:
    Bits = 0x40000004 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           (getReg(MI.getOperand(2)) << 10);
    break;
  case NDS32::XORrr:
    Bits = 0x40000003 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           (getReg(MI.getOperand(2)) << 10);
    break;
  case NDS32::SLLrr:
    Bits = 0x4000000c | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           (getReg(MI.getOperand(2)) << 10);
    break;
  case NDS32::SRLrr:
    Bits = 0x4000000d | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           (getReg(MI.getOperand(2)) << 10);
    break;
  case NDS32::SRArr:
    Bits = 0x4000000e | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           (getReg(MI.getOperand(2)) << 10);
    break;
  case NDS32::ANDri:
    Bits = 0x54000000 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           getImm16(MI, MI.getOperand(2), Fixups, STI);
    break;
  case NDS32::ORri:
    Bits = 0x58000000 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           getImm16(MI, MI.getOperand(2), Fixups, STI);
    break;
  case NDS32::XORri:
    Bits = 0x56000000 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           getImm16(MI, MI.getOperand(2), Fixups, STI);
    break;
  case NDS32::SLLIri:
    Bits = 0x40000008 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           ((static_cast<uint32_t>(MI.getOperand(2).getImm()) & 0x1f) << 10);
    break;
  case NDS32::SRLIri:
    Bits = 0x40000009 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           ((static_cast<uint32_t>(MI.getOperand(2).getImm()) & 0x1f) << 10);
    break;
  case NDS32::SRAIri:
    Bits = 0x4000000a | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           ((static_cast<uint32_t>(MI.getOperand(2).getImm()) & 0x1f) << 10);
    break;
  case NDS32::SLT:
    Bits = 0x40000006 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           (getReg(MI.getOperand(2)) << 10);
    break;
  case NDS32::SLTS:
    Bits = 0x40000007 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           (getReg(MI.getOperand(2)) << 10);
    break;
  case NDS32::SLTI:
    Bits = 0x5c000000 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           getImm16(MI, MI.getOperand(2), Fixups, STI);
    break;
  case NDS32::SLTSI:
    Bits = 0x5e000000 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           getImm16(MI, MI.getOperand(2), Fixups, STI);
    break;
  case NDS32::BGEZ:
    Bits = 0x4e040000 | (getReg(MI.getOperand(0)) << 20) |
           encodeBranchTarget(MI.getOperand(1), Fixups,
                              static_cast<MCFixupKind>(NDS32::fixup_nds32_17_pcrel));
    break;
  case NDS32::BLTZ:
    Bits = 0x4e050000 | (getReg(MI.getOperand(0)) << 20) |
           encodeBranchTarget(MI.getOperand(1), Fixups,
                              static_cast<MCFixupKind>(NDS32::fixup_nds32_17_pcrel));
    break;
  case NDS32::BGTZ:
    Bits = 0x4e060000 | (getReg(MI.getOperand(0)) << 20) |
           encodeBranchTarget(MI.getOperand(1), Fixups,
                              static_cast<MCFixupKind>(NDS32::fixup_nds32_17_pcrel));
    break;
  case NDS32::BLEZ:
    Bits = 0x4e070000 | (getReg(MI.getOperand(0)) << 20) |
           encodeBranchTarget(MI.getOperand(1), Fixups,
                              static_cast<MCFixupKind>(NDS32::fixup_nds32_17_pcrel));
    break;
  case NDS32::CLZ:
    Bits = 0x42000007 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15);
    break;
  case NDS32::WSBH:
    Bits = 0x40000014 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15);
    break;
  case NDS32::ROTRIri:
    Bits = 0x4000000b | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           ((static_cast<uint32_t>(MI.getOperand(2).getImm()) & 0x1f) << 10);
    break;
  // Conditional moves and MAC ops carry a tied $dstin in operand 1; the encoded
  // fields are dst (operand 0), src/a (operand 2), cond/b (operand 3).
  case NDS32::CMOVZ:
    Bits = 0x4000001a | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(2)) << 15) |
           (getReg(MI.getOperand(3)) << 10);
    break;
  case NDS32::CMOVN:
    Bits = 0x4000001b | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(2)) << 15) |
           (getReg(MI.getOperand(3)) << 10);
    break;
  case NDS32::MADDR32:
    Bits = 0x42000073 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(2)) << 15) |
           (getReg(MI.getOperand(3)) << 10);
    break;
  case NDS32::MSUBR32:
    Bits = 0x42000075 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(2)) << 15) |
           (getReg(MI.getOperand(3)) << 10);
    break;
  case NDS32::BITCI:
    Bits = 0x66000000 | (getReg(MI.getOperand(0)) << 20) |
           (getReg(MI.getOperand(1)) << 15) |
           (static_cast<uint32_t>(MI.getOperand(2).getImm()) & 0x7fff);
    break;
  default:
    report_fatal_error("NDS32 instruction encoding is not implemented");
  }

  raw_svector_ostream OS(CB);
  support::endian::Writer Writer(
      OS, IsLittleEndian ? llvm::endianness::little : llvm::endianness::big);
  Writer.write<uint32_t>(Bits);
}

MCCodeEmitter *llvm::createNDS32MCCodeEmitter(const MCInstrInfo &MCII,
                                              MCContext &Ctx) {
  bool IsLittleEndian = Ctx.getTargetTriple().isLittleEndian();
  return new NDS32MCCodeEmitter(*Ctx.getRegisterInfo(), IsLittleEndian);
}
