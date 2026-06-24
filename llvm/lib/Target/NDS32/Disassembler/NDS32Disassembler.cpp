//===-- NDS32Disassembler.cpp - Disassembler for NDS32 -------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/NDS32MCTargetDesc.h"
#include "TargetInfo/NDS32TargetInfo.h"
#include "llvm/MC/MCDecoder.h"
#include "llvm/MC/MCDecoderOps.h"
#include "llvm/MC/MCDisassembler/MCDisassembler.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/Endian.h"

using namespace llvm;
using namespace llvm::MCD;

using DecodeStatus = MCDisassembler::DecodeStatus;

#define DEBUG_TYPE "nds32-disassembler"

namespace {
class NDS32Disassembler : public MCDisassembler {
public:
  NDS32Disassembler(const MCSubtargetInfo &STI, MCContext &Ctx)
      : MCDisassembler(STI, Ctx) {}

  DecodeStatus getInstruction(MCInst &MI, uint64_t &Size,
                              ArrayRef<uint8_t> Bytes, uint64_t Address,
                              raw_ostream &CStream) const override;
};
} // namespace

// $r0-$r31 / $fs0-$fs31 are consecutive in the generated register enum.
static const MCPhysReg GPRTable[] = {
    NDS32::R0,  NDS32::R1,  NDS32::R2,  NDS32::R3,  NDS32::R4,  NDS32::R5,
    NDS32::R6,  NDS32::R7,  NDS32::R8,  NDS32::R9,  NDS32::R10, NDS32::R11,
    NDS32::R12, NDS32::R13, NDS32::R14, NDS32::R15, NDS32::R16, NDS32::R17,
    NDS32::R18, NDS32::R19, NDS32::R20, NDS32::R21, NDS32::R22, NDS32::R23,
    NDS32::R24, NDS32::R25, NDS32::R26, NDS32::R27, NDS32::R28, NDS32::R29,
    NDS32::R30, NDS32::R31};

static const MCPhysReg FPR32Table[] = {
    NDS32::FS0,  NDS32::FS1,  NDS32::FS2,  NDS32::FS3,  NDS32::FS4,  NDS32::FS5,
    NDS32::FS6,  NDS32::FS7,  NDS32::FS8,  NDS32::FS9,  NDS32::FS10, NDS32::FS11,
    NDS32::FS12, NDS32::FS13, NDS32::FS14, NDS32::FS15, NDS32::FS16, NDS32::FS17,
    NDS32::FS18, NDS32::FS19, NDS32::FS20, NDS32::FS21, NDS32::FS22, NDS32::FS23,
    NDS32::FS24, NDS32::FS25, NDS32::FS26, NDS32::FS27, NDS32::FS28, NDS32::FS29,
    NDS32::FS30, NDS32::FS31};

static DecodeStatus DecodeGPRRegisterClass(MCInst &Inst, unsigned RegNo,
                                           uint64_t Address,
                                           const MCDisassembler *Decoder) {
  if (RegNo > 31)
    return MCDisassembler::Fail;
  Inst.addOperand(MCOperand::createReg(GPRTable[RegNo]));
  return MCDisassembler::Success;
}

static DecodeStatus DecodeFPR32RegisterClass(MCInst &Inst, unsigned RegNo,
                                             uint64_t Address,
                                             const MCDisassembler *Decoder) {
  if (RegNo > 31)
    return MCDisassembler::Fail;
  Inst.addOperand(MCOperand::createReg(FPR32Table[RegNo]));
  return MCDisassembler::Success;
}

// Compound memory operand [19:0] = base[19:15] + scaled offset[14:0]. The
// offset is rescaled to bytes for printing/round-tripping.
template <unsigned Scale>
static DecodeStatus decodeMem(MCInst &Inst, unsigned Imm, uint64_t Address,
                              const MCDisassembler *Decoder) {
  unsigned Base = (Imm >> 15) & 0x1f;
  unsigned Off = Imm & 0x7fff;
  Inst.addOperand(MCOperand::createReg(GPRTable[Base]));
  Inst.addOperand(MCOperand::createImm(Off << Scale));
  return MCDisassembler::Success;
}

static DecodeStatus decodeMemWords(MCInst &Inst, unsigned Imm, uint64_t Addr,
                                   const MCDisassembler *D) {
  return decodeMem<2>(Inst, Imm, Addr, D);
}
static DecodeStatus decodeMemHalfwords(MCInst &Inst, unsigned Imm,
                                       uint64_t Addr, const MCDisassembler *D) {
  return decodeMem<1>(Inst, Imm, Addr, D);
}
static DecodeStatus decodeMemBytes(MCInst &Inst, unsigned Imm, uint64_t Addr,
                                   const MCDisassembler *D) {
  return decodeMem<0>(Inst, Imm, Addr, D);
}

// Register-offset memory [19:8] = base[11:7] + index[6:2] + scale[1:0].
static DecodeStatus decodeRegOffset(MCInst &Inst, unsigned Imm, uint64_t Addr,
                                    const MCDisassembler *Decoder) {
  unsigned Base = (Imm >> 7) & 0x1f;
  unsigned Index = (Imm >> 2) & 0x1f;
  unsigned Scale = Imm & 0x3;
  Inst.addOperand(MCOperand::createReg(GPRTable[Base]));
  Inst.addOperand(MCOperand::createReg(GPRTable[Index]));
  Inst.addOperand(MCOperand::createImm(Scale));
  return MCDisassembler::Success;
}

#include "NDS32GenDisassemblerTables.inc"

// Both 16- and 32-bit forms are decoded from a 32-bit word (InsnBitWidth is the
// primary template defined in the generated tables above).
namespace {
template <> constexpr uint32_t InsnBitWidth<uint32_t> = 32;
} // namespace

DecodeStatus NDS32Disassembler::getInstruction(MCInst &MI, uint64_t &Size,
                                               ArrayRef<uint8_t> Bytes,
                                               uint64_t Address,
                                               raw_ostream &CStream) const {
  // 16-bit forms have the top bit of the first (big-endian) halfword set;
  // 32-bit forms have bit 31 clear.
  if (Bytes.size() >= 2 && (Bytes[0] & 0x80)) {
    uint32_t Insn = (Bytes[0] << 8) | Bytes[1];
    if (decodeInstruction(DecoderTable16, MI, Insn, Address, this, STI) ==
        MCDisassembler::Success) {
      Size = 2;
      return MCDisassembler::Success;
    }
    Size = 0;
    return MCDisassembler::Fail;
  }
  if (Bytes.size() < 4) {
    Size = 0;
    return MCDisassembler::Fail;
  }
  uint32_t Insn = support::endian::read32be(Bytes.data());
  if (decodeInstruction(DecoderTable32, MI, Insn, Address, this, STI) ==
      MCDisassembler::Success) {
    Size = 4;
    return MCDisassembler::Success;
  }
  Size = 0;
  return MCDisassembler::Fail;
}

static MCDisassembler *createNDS32Disassembler(const Target &T,
                                               const MCSubtargetInfo &STI,
                                               MCContext &Ctx) {
  return new NDS32Disassembler(STI, Ctx);
}

extern "C" LLVM_EXTERNAL_VISIBILITY void LLVMInitializeNDS32Disassembler() {
  TargetRegistry::RegisterMCDisassembler(getTheNDS32Target(),
                                         createNDS32Disassembler);
  TargetRegistry::RegisterMCDisassembler(getTheNDS32leTarget(),
                                         createNDS32Disassembler);
  TargetRegistry::RegisterMCDisassembler(getTheNDS32beTarget(),
                                         createNDS32Disassembler);
}
