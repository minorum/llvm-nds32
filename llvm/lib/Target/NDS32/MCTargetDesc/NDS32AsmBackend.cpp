//===-- NDS32AsmBackend.cpp - NDS32 Assembler Backend ---------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/NDS32MCTargetDesc.h"
#include "llvm/MC/MCAsmBackend.h"
#include "llvm/MC/MCAssembler.h"
#include "llvm/MC/MCELFObjectWriter.h"
#include "llvm/MC/MCObjectWriter.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/Support/EndianStream.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/TargetParser/Triple.h"

using namespace llvm;

namespace {
class NDS32AsmBackend : public MCAsmBackend {
  Triple::OSType OSType;
  llvm::endianness Endian;

public:
  NDS32AsmBackend(Triple::OSType OSType, llvm::endianness Endian)
      : MCAsmBackend(Endian), OSType(OSType), Endian(Endian) {}

  void applyFixup(const MCFragment &, const MCFixup &Fixup,
                  const MCValue &Target, uint8_t *Data, uint64_t Value,
                  bool IsResolved) override;

  std::unique_ptr<MCObjectTargetWriter>
  createObjectTargetWriter() const override;

  MCFixupKindInfo getFixupKindInfo(MCFixupKind Kind) const override;

  bool writeNopData(raw_ostream &OS, uint64_t Count,
                    const MCSubtargetInfo *STI) const override;
};
} // namespace

MCFixupKindInfo
NDS32AsmBackend::getFixupKindInfo(MCFixupKind Kind) const {
  const static MCFixupKindInfo Infos[NDS32::NumTargetFixupKinds] = {
    // This table must be in the same order of enum in NDS32FixupKinds.h.
    //
    // name, offset, bits, flags
    // PC-relativeness is now carried per-fixup (MCFixup::PCRel), not via a
    // FKF flag, so the flags field is 0 here.
    {"fixup_nds32_15_pcrel", 0, 15, 0},
    {"fixup_nds32_17_pcrel", 0, 17, 0},
    {"fixup_nds32_25_pcrel", 0, 25, 0},
    {"fixup_nds32_hi20",     0, 20, 0},
    {"fixup_nds32_lo12s0",   0, 12, 0},
    {"fixup_nds32_lo12s2",   0, 12, 0},
    {"fixup_nds32_gotoff_hi20", 0, 20, 0},
    {"fixup_nds32_gotoff_lo12", 0, 15, 0},
    {"fixup_nds32_got_hi20",    0, 20, 0},
    {"fixup_nds32_got_lo12",    0, 15, 0},
    {"fixup_nds32_tls_le_hi20", 0, 20, 0},
    {"fixup_nds32_tls_le_lo12", 0, 15, 0}
  };

  static_assert((std::size(Infos)) == NDS32::NumTargetFixupKinds,
                "Not all fixup kinds added to Infos array");

  if (Kind < FirstTargetFixupKind)
    return MCAsmBackend::getFixupKindInfo(Kind);

  return Infos[Kind - FirstTargetFixupKind];
}

void NDS32AsmBackend::applyFixup(const MCFragment &F, const MCFixup &Fixup,
                                 const MCValue &Target, uint8_t *Data,
                                 uint64_t Value, bool IsResolved) {
  maybeAddReloc(F, Fixup, Target, Value, IsResolved);
  if (Value == 0)
    return;

  unsigned Kind = Fixup.getKind();
  uint32_t Mask = 0xffffffff;

  if (Kind >= FirstTargetFixupKind) {
    switch (Kind) {
    case NDS32::fixup_nds32_15_pcrel:
      // beq/bne (BR1): 14-bit disp field (bits [13:0]); the "15" is the
      // PC-relative range (disp << 1). Bit 14 is the eq/ne sub-opcode, so the
      // mask must NOT reach it or an internally-resolved bne becomes beq.
      Value = (Value / 2) & 0x00003fff;
      Mask = 0x00003fff;
      break;
    case NDS32::fixup_nds32_17_pcrel:
      // beqz/bnez/etc. (BR2): 16-bit disp field (bits [15:0]); the "17" is the
      // PC-relative range (disp << 1). Bit 16 is the eq/ne sub-opcode, so the
      // mask must stay within 16 bits or an internally-resolved bnez becomes
      // beqz.
      Value = (Value / 2) & 0x0000ffff;
      Mask = 0x0000ffff;
      break;
    case NDS32::fixup_nds32_25_pcrel:
      Value = (Value / 2) & 0x01ffffff;
      Mask = 0x01ffffff;
      break;
    case NDS32::fixup_nds32_hi20:
      Value = (Value >> 12) & 0x000fffff;
      Mask = 0x000fffff;
      break;
    case NDS32::fixup_nds32_lo12s0:
      Value = Value & 0x00000fff;
      Mask = 0x0000ffff; // imm16 field in addi
      break;
    case NDS32::fixup_nds32_lo12s2:
      Value = (Value & 0x00000fff) >> 2;
      Mask = 0x00007fff; // offset15 in words in lwi/swi
      break;
    // PIC fixups are always resolved by the linker (Value == 0 here), but mask
    // the same fields as their absolute counterparts for completeness.
    case NDS32::fixup_nds32_gotoff_hi20:
    case NDS32::fixup_nds32_got_hi20:
    case NDS32::fixup_nds32_tls_le_hi20:
      Value = (Value >> 12) & 0x000fffff;
      Mask = 0x000fffff;
      break;
    case NDS32::fixup_nds32_gotoff_lo12:
    case NDS32::fixup_nds32_got_lo12:
    case NDS32::fixup_nds32_tls_le_lo12:
      Value = Value & 0x00007fff; // ori imm15
      Mask = 0x00007fff;
      break;
    default:
      llvm_unreachable("Invalid target fixup kind");
    }
  }
  // Generic fixups (e.g. FK_Data_4) write the full value with the default mask.

  // In LLVM 22, Data already points at the first byte of the fixup offset.
  uint32_t Cur = support::endian::read32(Data, Endian);
  Cur &= ~Mask;
  Cur |= static_cast<uint32_t>(Value) & Mask;
  support::endian::write32(Data, Cur, Endian);
}

std::unique_ptr<MCObjectTargetWriter>
NDS32AsmBackend::createObjectTargetWriter() const {
  return createNDS32ELFObjectWriter(MCELFObjectTargetWriter::getOSABI(OSType));
}

bool NDS32AsmBackend::writeNopData(raw_ostream &OS, uint64_t Count,
                                   const MCSubtargetInfo *STI) const {
  if (Count % 4 != 0)
    return false;

  for (uint64_t I = 0; I < Count; I += 4)
    support::endian::write<uint32_t>(OS, 0x40000009, Endian);

  return true;
}

MCAsmBackend *llvm::createNDS32AsmBackend(const Target &T,
                                          const MCSubtargetInfo &STI,
                                          const MCRegisterInfo &MRI,
                                          const MCTargetOptions &Options) {
  const Triple &TT = STI.getTargetTriple();
  return new NDS32AsmBackend(TT.getOS(), TT.isLittleEndian()
                                             ? llvm::endianness::little
                                             : llvm::endianness::big);
}
