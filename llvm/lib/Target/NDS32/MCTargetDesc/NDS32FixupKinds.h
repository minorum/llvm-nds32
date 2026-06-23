//===-- NDS32FixupKinds.h - NDS32 Specific Fixup Entries --------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_NDS32_MCTARGETDESC_NDS32FIXUPKINDS_H
#define LLVM_LIB_TARGET_NDS32_MCTARGETDESC_NDS32FIXUPKINDS_H

#include "llvm/MC/MCFixup.h"

namespace llvm {
namespace NDS32 {
enum Fixups {
  // A 15-bit PC relative fixup (for beq/bne conditional branches)
  fixup_nds32_15_pcrel = FirstTargetFixupKind,
  // A 17-bit PC relative fixup (for beqz/bnez conditional branches)
  fixup_nds32_17_pcrel,
  // A 25-bit PC relative fixup (for j/jal branches)
  fixup_nds32_25_pcrel,
  // A 20-bit absolute fixup for sethi high bits
  fixup_nds32_hi20,
  // A 12-bit absolute fixup for addi low offset
  fixup_nds32_lo12s0,
  // A 12-bit absolute fixup for lwi/swi low offset (word aligned)
  fixup_nds32_lo12s2,
  // PIC fixups (append-only): GOT-base-relative and GOT-entry offsets.
  fixup_nds32_gotoff_hi20,
  fixup_nds32_gotoff_lo12,
  fixup_nds32_got_hi20,
  fixup_nds32_got_lo12,
  fixup_nds32_tls_le_hi20,
  fixup_nds32_tls_le_lo12,

  LastTargetFixupKind,
  NumTargetFixupKinds = LastTargetFixupKind - FirstTargetFixupKind
};
} // namespace NDS32
} // namespace llvm

#endif // LLVM_LIB_TARGET_NDS32_MCTARGETDESC_NDS32FIXUPKINDS_H
