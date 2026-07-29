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
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCDisassembler/MCDisassembler.h"
#include "llvm/MC/MCInst.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/Endian.h"
#include "llvm/Support/MathExtras.h"

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

  // On a decode failure, advance by one halfword rather than the default one
  // byte: NDS32 is halfword-aligned, so skipping a single byte would misalign
  // (and corrupt the decode of) every following instruction. Skipping 2 keeps
  // the stream aligned so decodable instructions after an unknown one still
  // disassemble correctly.
  uint64_t suggestBytesToSkip(ArrayRef<uint8_t> Bytes,
                              uint64_t Address) const override {
    return 2;
  }
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

// System registers (mfsr/mtsr). Unlike GPR/FPR32 these cannot use a flat table:
// the operand is a 15-bit SRIDX whose assigned values are sparse (~136 of
// 32768), so look the encoding up in the SR register class instead. An
// unassigned SRIDX must Fail rather than decode to some wrong name -- the point
// of this disassembler is firmware RE, where a plausible-but-wrong mnemonic is
// worse than a refusal.
static DecodeStatus DecodeSRRegisterClass(MCInst &Inst, unsigned RegNo,
                                          uint64_t Address,
                                          const MCDisassembler *Decoder) {
  const MCRegisterInfo *MRI = Decoder->getContext().getRegisterInfo();
  const MCRegisterClass &RC = MRI->getRegClass(NDS32::SRRegClassID);
  for (unsigned I = 0, E = RC.getNumRegs(); I != E; ++I) {
    MCRegister Reg = RC.getRegister(I);
    if (MRI->getEncodingValue(Reg) == RegNo) {
      Inst.addOperand(MCOperand::createReg(Reg));
      return MCDisassembler::Success;
    }
  }
  return MCDisassembler::Fail;
}

// Add a PC-relative branch/call target. If a symbolizer is installed (as
// llvm-objdump does), resolve the absolute target to a symbol; otherwise leave
// the relative byte displacement (which the registered MCInstrAnalysis turns
// back into an absolute target for annotation).
static DecodeStatus addBranchTarget(MCInst &Inst, uint64_t Address,
                                    int64_t Offset, unsigned InstSize,
                                    const MCDisassembler *Decoder) {
  if (!Decoder->tryAddingSymbolicOperand(Inst, Address + Offset, Address,
                                         /*IsBranch=*/true, /*Offset=*/0,
                                         /*OpSize=*/0, InstSize))
    Inst.addOperand(MCOperand::createImm(Offset));
  return MCDisassembler::Success;
}

// 16-bit short-branch target: 8-bit signed displacement, scaled by 2.
static DecodeStatus decodeBr9(MCInst &Inst, unsigned Imm, uint64_t Address,
                              const MCDisassembler *Decoder) {
  return addBranchTarget(Inst, Address, SignExtend64<8>(Imm) * 2,
                         /*InstSize=*/2, Decoder);
}

// 16-bit add45/addi45 4-bit register field: codes 0-11 -> r0-r11,
// codes 12-15 -> r16-r19 (inverse of encodeGPR4).
static DecodeStatus decodeGPR4(MCInst &Inst, unsigned Code, uint64_t Address,
                               const MCDisassembler *Decoder) {
  if (Code > 15)
    return MCDisassembler::Fail;
  unsigned RegNo = Code <= 11 ? Code : Code + 4;
  Inst.addOperand(MCOperand::createReg(GPRTable[RegNo]));
  return MCDisassembler::Success;
}

// Compound memory operand [19:0] = base[19:15] + scaled offset[14:0]. The
// 15-bit offset is signed (lwi/swi accept negative displacements); it is
// sign-extended and rescaled to bytes for printing/round-tripping.
template <unsigned Scale>
static DecodeStatus decodeMem(MCInst &Inst, unsigned Imm, uint64_t Address,
                              const MCDisassembler *Decoder) {
  unsigned Base = (Imm >> 15) & 0x1f;
  int32_t Off = SignExtend32<15>(Imm & 0x7fff);
  Inst.addOperand(MCOperand::createReg(GPRTable[Base]));
  Inst.addOperand(MCOperand::createImm(Off << Scale));
  return MCDisassembler::Success;
}

// Signed I-type immediates. The generated decoder hands us the raw field
// already masked to its declared width, so we only sign-extend.
static DecodeStatus decodeSImm15(MCInst &Inst, unsigned Imm, uint64_t Address,
                                 const MCDisassembler *Decoder) {
  Inst.addOperand(MCOperand::createImm(SignExtend32<15>(Imm)));
  return MCDisassembler::Success;
}
static DecodeStatus decodeSImm20(MCInst &Inst, unsigned Imm, uint64_t Address,
                                 const MCDisassembler *Decoder) {
  Inst.addOperand(MCOperand::createImm(SignExtend32<20>(Imm)));
  return MCDisassembler::Success;
}
// 16-bit movi55: 5-bit signed immediate.
static DecodeStatus decodeSImm5(MCInst &Inst, unsigned Imm, uint64_t Address,
                                const MCDisassembler *Decoder) {
  Inst.addOperand(MCOperand::createImm(SignExtend32<5>(Imm)));
  return MCDisassembler::Success;
}

// PC-relative branch/jump targets. The displacement is encoded in halfword
// units (scaled by 2) and is signed.
template <unsigned Bits>
static DecodeStatus decodeBranch(MCInst &Inst, unsigned Imm, uint64_t Address,
                                 const MCDisassembler *Decoder) {
  return addBranchTarget(Inst, Address, SignExtend64<Bits>(Imm) * 2,
                         /*InstSize=*/4, Decoder);
}
static DecodeStatus decodeBr25(MCInst &Inst, unsigned Imm, uint64_t A,
                               const MCDisassembler *D) {
  return decodeBranch<24>(Inst, Imm, A, D);
}
static DecodeStatus decodeBr17(MCInst &Inst, unsigned Imm, uint64_t A,
                               const MCDisassembler *D) {
  return decodeBranch<16>(Inst, Imm, A, D);
}
static DecodeStatus decodeBr15(MCInst &Inst, unsigned Imm, uint64_t A,
                               const MCDisassembler *D) {
  return decodeBranch<14>(Inst, Imm, A, D);
}

// 16-bit lwi333/swi333: 3-bit offset in word units, rescaled to bytes.
static DecodeStatus decodeOff3Words(MCInst &Inst, unsigned Imm, uint64_t Address,
                                    const MCDisassembler *Decoder) {
  Inst.addOperand(MCOperand::createImm((Imm & 0x7) << 2));
  return MCDisassembler::Success;
}
// 16-bit lhi333/shi333: 3-bit offset in halfword units.
static DecodeStatus decodeOff3Half(MCInst &Inst, unsigned Imm, uint64_t Address,
                                   const MCDisassembler *Decoder) {
  Inst.addOperand(MCOperand::createImm((Imm & 0x7) << 1));
  return MCDisassembler::Success;
}
// 16-bit lbi333/sbi333: 3-bit byte offset (unscaled).
static DecodeStatus decodeOff3Byte(MCInst &Inst, unsigned Imm, uint64_t Address,
                                   const MCDisassembler *Decoder) {
  Inst.addOperand(MCOperand::createImm(Imm & 0x7));
  return MCDisassembler::Success;
}

// Post-increment immediate: a signed 15-bit value in element units, rescaled to
// bytes (mirrors encodePostInc<Shift>).
template <unsigned Shift>
static DecodeStatus decodePostInc(MCInst &Inst, unsigned Imm, uint64_t Address,
                                  const MCDisassembler *Decoder) {
  Inst.addOperand(MCOperand::createImm(SignExtend32<15>(Imm) << Shift));
  return MCDisassembler::Success;
}
static DecodeStatus decodePostByte(MCInst &Inst, unsigned Imm, uint64_t A,
                                   const MCDisassembler *D) {
  return decodePostInc<0>(Inst, Imm, A, D);
}
static DecodeStatus decodePostHalf(MCInst &Inst, unsigned Imm, uint64_t A,
                                   const MCDisassembler *D) {
  return decodePostInc<1>(Inst, Imm, A, D);
}
static DecodeStatus decodePostWord(MCInst &Inst, unsigned Imm, uint64_t A,
                                   const MCDisassembler *D) {
  return decodePostInc<2>(Inst, Imm, A, D);
}

// 16-bit SP/base-relative word offsets (unsigned, rescaled to bytes).
template <unsigned Width>
static DecodeStatus decodeOffWords(MCInst &Inst, unsigned Imm, uint64_t Address,
                                   const MCDisassembler *Decoder) {
  Inst.addOperand(MCOperand::createImm((Imm & ((1u << Width) - 1)) << 2));
  return MCDisassembler::Success;
}
static DecodeStatus decodeOff7Words(MCInst &Inst, unsigned Imm, uint64_t A,
                                    const MCDisassembler *D) {
  return decodeOffWords<7>(Inst, Imm, A, D);
}
static DecodeStatus decodeOff6Words(MCInst &Inst, unsigned Imm, uint64_t A,
                                    const MCDisassembler *D) {
  return decodeOffWords<6>(Inst, Imm, A, D);
}

// 16-bit addi10.sp: signed 10-bit byte immediate.
static DecodeStatus decodeSImm10(MCInst &Inst, unsigned Imm, uint64_t Address,
                                 const MCDisassembler *Decoder) {
  Inst.addOperand(MCOperand::createImm(SignExtend32<10>(Imm)));
  return MCDisassembler::Success;
}

// 16-bit movpi45: loads a 5-bit immediate biased by +16 (range 16..47).
static DecodeStatus decodeMovpi(MCInst &Inst, unsigned Imm, uint64_t Address,
                                const MCDisassembler *Decoder) {
  Inst.addOperand(MCOperand::createImm((Imm & 0x1f) + 16));
  return MCDisassembler::Success;
}

// 16-bit movd44: a 4-bit field selects an even register pair (code*2).
static DecodeStatus decodeEvenGPR(MCInst &Inst, unsigned Code, uint64_t Address,
                                  const MCDisassembler *Decoder) {
  Inst.addOperand(MCOperand::createReg(GPRTable[(Code & 0xf) << 1]));
  return MCDisassembler::Success;
}

// beqc/bnec: signed 11-bit compare immediate.
static DecodeStatus decodeSImm11(MCInst &Inst, unsigned Imm, uint64_t Address,
                                 const MCDisassembler *Decoder) {
  Inst.addOperand(MCOperand::createImm(SignExtend32<11>(Imm)));
  return MCDisassembler::Success;
}

// gp-relative word load/store: signed 17-bit offset, rescaled to bytes.
static DecodeStatus decodeOff17Words(MCInst &Inst, unsigned Imm,
                                     uint64_t Address,
                                     const MCDisassembler *Decoder) {
  Inst.addOperand(MCOperand::createImm(SignExtend32<17>(Imm) << 2));
  return MCDisassembler::Success;
}
// gp-relative byte load: signed 17-bit byte offset (unscaled).
static DecodeStatus decodeOff17Byte(MCInst &Inst, unsigned Imm,
                                    uint64_t Address,
                                    const MCDisassembler *Decoder) {
  Inst.addOperand(MCOperand::createImm(SignExtend32<17>(Imm)));
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
  // NDS32 instructions are encoded big-endian regardless of the data
  // endianness selected by the triple (verified against the Andes toolchain:
  // `gcc -EB` and `gcc -EL` emit byte-identical .text; only .data is swapped).
  // So instruction parcels are always read big-endian. The instruction-length
  // bit is bit 15 of the first halfword: set selects a 16-bit form, clear a
  // 32-bit form.
  if (Bytes.size() >= 2) {
    uint16_t HW = support::endian::read16be(Bytes.data());
    if (HW & 0x8000) {
      if (decodeInstruction(DecoderTable16, MI, HW, Address, this, STI) ==
          MCDisassembler::Success) {
        Size = 2;
        return MCDisassembler::Success;
      }
      Size = 0;
      return MCDisassembler::Fail;
    }
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
