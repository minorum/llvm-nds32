//===-- NDS32MCTargetDesc.h - NDS32 Target Descriptions ---------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_NDS32_MCTARGETDESC_NDS32MCTARGETDESC_H
#define LLVM_LIB_TARGET_NDS32_MCTARGETDESC_NDS32MCTARGETDESC_H

#include "NDS32FixupKinds.h"
#include "llvm/Support/DataTypes.h"
#include <memory>

namespace llvm {
class MCAsmBackend;
class MCCodeEmitter;
class MCContext;
class MCInstrInfo;
class MCObjectTargetWriter;
class MCRegisterInfo;
class MCSubtargetInfo;
class MCTargetOptions;
class Target;

Target &getTheNDS32Target();
Target &getTheNDS32leTarget();
Target &getTheNDS32beTarget();

MCCodeEmitter *createNDS32MCCodeEmitter(const MCInstrInfo &MCII,
                                        MCContext &Ctx);
MCAsmBackend *createNDS32AsmBackend(const Target &T,
                                    const MCSubtargetInfo &STI,
                                    const MCRegisterInfo &MRI,
                                    const MCTargetOptions &Options);
std::unique_ptr<MCObjectTargetWriter> createNDS32ELFObjectWriter(uint8_t OSABI);

namespace NDS32II {
enum TOF {
  MO_NO_FLAG = 0,
  MO_HI20,
  MO_LO12S0,
  MO_LO12S2,
  // PIC relocations (append-only). GOTOFF: a symbol's offset from the GOT base
  // ($gp); GOT: the offset of the symbol's GOT entry from $gp.
  MO_GOTOFF_HI20,
  MO_GOTOFF_LO12,
  MO_GOT_HI20,
  MO_GOT_LO12,
  // Thread-local storage, local-exec model: offset from the thread pointer.
  MO_TLS_LE_HI20,
  MO_TLS_LE_LO12,
};
} // namespace NDS32II

} // End llvm namespace

#define GET_REGINFO_ENUM
#include "NDS32GenRegisterInfo.inc"

#define GET_INSTRINFO_ENUM
#define GET_INSTRINFO_MC_HELPER_DECLS
#include "NDS32GenInstrInfo.inc"

#define GET_SUBTARGETINFO_ENUM
#include "NDS32GenSubtargetInfo.inc"

#endif // LLVM_LIB_TARGET_NDS32_MCTARGETDESC_NDS32MCTARGETDESC_H
