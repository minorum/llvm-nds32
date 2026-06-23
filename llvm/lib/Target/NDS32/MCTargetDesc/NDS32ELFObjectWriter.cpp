//===-- NDS32ELFObjectWriter.cpp - NDS32 ELF Writer -----------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/NDS32MCTargetDesc.h"
#include "llvm/BinaryFormat/ELF.h"
#include "llvm/MC/MCELFObjectWriter.h"
#include "llvm/MC/MCFixup.h"
#include "llvm/MC/MCObjectWriter.h"
#include "llvm/Support/ErrorHandling.h"

using namespace llvm;

namespace {
enum NDS32Relocs {
  R_NDS32_32_RELA = 20,
  R_NDS32_15_PCREL_RELA = 23,
  R_NDS32_17_PCREL_RELA = 24,
  R_NDS32_25_PCREL_RELA = 25,
  R_NDS32_HI20_RELA = 26,
  R_NDS32_LO12S2_RELA = 28,
  R_NDS32_LO12S0_RELA = 30,
  // PIC relocations (binutils-authoritative numbers).
  R_NDS32_GOT_HI20 = 45,
  R_NDS32_GOT_LO12 = 46,
  R_NDS32_GOTOFF_HI20 = 49,
  R_NDS32_GOTOFF_LO12 = 50,
  R_NDS32_TLS_LE_HI20 = 98,
  R_NDS32_TLS_LE_LO12 = 99,
};

class NDS32ELFObjectWriter : public MCELFObjectTargetWriter {
public:
  explicit NDS32ELFObjectWriter(uint8_t OSABI)
      : MCELFObjectTargetWriter(/*Is64Bit=*/false, OSABI, ELF::EM_NDS32,
                                /*HasRelocationAddend=*/true) {}

protected:
  unsigned getRelocType(const MCFixup &Fixup, const MCValue &Target,
                        bool IsPCRel) const override;
};
} // namespace

unsigned NDS32ELFObjectWriter::getRelocType(const MCFixup &Fixup,
                                            const MCValue &Target,
                                            bool IsPCRel) const {
  unsigned Kind = Fixup.getKind();
  if (Kind >= FirstTargetFixupKind) {
    switch (Kind) {
    case NDS32::fixup_nds32_15_pcrel:
      return R_NDS32_15_PCREL_RELA;
    case NDS32::fixup_nds32_17_pcrel:
      return R_NDS32_17_PCREL_RELA;
    case NDS32::fixup_nds32_25_pcrel:
      return R_NDS32_25_PCREL_RELA;
    case NDS32::fixup_nds32_hi20:
      return R_NDS32_HI20_RELA;
    case NDS32::fixup_nds32_lo12s0:
      return R_NDS32_LO12S0_RELA;
    case NDS32::fixup_nds32_lo12s2:
      return R_NDS32_LO12S2_RELA;
    case NDS32::fixup_nds32_gotoff_hi20:
      return R_NDS32_GOTOFF_HI20;
    case NDS32::fixup_nds32_gotoff_lo12:
      return R_NDS32_GOTOFF_LO12;
    case NDS32::fixup_nds32_got_hi20:
      return R_NDS32_GOT_HI20;
    case NDS32::fixup_nds32_got_lo12:
      return R_NDS32_GOT_LO12;
    case NDS32::fixup_nds32_tls_le_hi20:
      return R_NDS32_TLS_LE_HI20;
    case NDS32::fixup_nds32_tls_le_lo12:
      return R_NDS32_TLS_LE_LO12;
    default:
      llvm_unreachable("Invalid target fixup kind");
    }
  }

  switch (Kind) {
  case FK_Data_4:
    return IsPCRel ? R_NDS32_25_PCREL_RELA : R_NDS32_32_RELA;
  default:
    report_fatal_error("unsupported NDS32 relocation kind");
  }
}

std::unique_ptr<MCObjectTargetWriter>
llvm::createNDS32ELFObjectWriter(uint8_t OSABI) {
  return std::make_unique<NDS32ELFObjectWriter>(OSABI);
}
