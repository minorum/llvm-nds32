//===-- NDS32ISelLowering.h - NDS32 DAG Lowering Interface ------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LIB_TARGET_NDS32_NDS32ISELLOWERING_H
#define LLVM_LIB_TARGET_NDS32_NDS32ISELLOWERING_H

#include "llvm/CodeGen/TargetLowering.h"

namespace llvm {
namespace NDS32ISD {
enum NodeType : unsigned {
  FIRST_NUMBER = ISD::BUILTIN_OP_END,

  /// Return with an optional glue operand.
  RET_FLAG,

  /// Wrapper node for global/external symbol addresses.
  Wrapper,

  /// Call instruction wrapper.
  CALL,

  /// Target-specific branch conditional node.
  BR_CC,

  /// Target-specific select: (SELECT_CC cond, trueval, falseval) chooses
  /// trueval when the i32 cond operand is nonzero, falseval otherwise.
  SELECT_CC,
};
} // namespace NDS32ISD

class NDS32Subtarget;

class NDS32TargetLowering : public TargetLowering {
public:
  explicit NDS32TargetLowering(const TargetMachine &TM, const NDS32Subtarget &STI);

  const char *getTargetNodeName(unsigned Opcode) const override;

  SDValue LowerFormalArguments(SDValue Chain, CallingConv::ID CallConv,
                               bool IsVarArg,
                               const SmallVectorImpl<ISD::InputArg> &Ins,
                               const SDLoc &DL, SelectionDAG &DAG,
                               SmallVectorImpl<SDValue> &InVals) const override;

  SDValue LowerReturn(SDValue Chain, CallingConv::ID CallConv, bool IsVarArg,
                      const SmallVectorImpl<ISD::OutputArg> &Outs,
                      const SmallVectorImpl<SDValue> &OutVals,
                      const SDLoc &DL, SelectionDAG &DAG) const override;

  bool CanLowerReturn(CallingConv::ID CallConv, MachineFunction &MF,
                      bool IsVarArg,
                      const SmallVectorImpl<ISD::OutputArg> &Outs,
                      LLVMContext &Context, const Type *RetTy) const override;

  SDValue LowerCall(TargetLowering::CallLoweringInfo &CLI,
                    SmallVectorImpl<SDValue> &InVals) const override;

  SDValue LowerCallResult(SDValue Chain, SDValue InGlue, CallingConv::ID CallConv,
                          bool IsVarArg, const SmallVectorImpl<ISD::InputArg> &Ins,
                          const SDLoc &DL, SelectionDAG &DAG,
                          SmallVectorImpl<SDValue> &InVals) const;

  SDValue LowerOperation(SDValue Op, SelectionDAG &DAG) const override;

  SDValue LowerGlobalAddress(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerExternalSymbol(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerConstantPool(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerJumpTable(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerBR_CC(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerSETCC(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerSELECT_CC(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerDYNAMIC_STACKALLOC(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerFRAMEADDR(SDValue Op, SelectionDAG &DAG) const;
  SDValue LowerRETURNADDR(SDValue Op, SelectionDAG &DAG) const;

  MachineBasicBlock *
  EmitInstrWithCustomInserter(MachineInstr &MI,
                              MachineBasicBlock *MBB) const override;

  // We have a single-cycle clz that is correct for a zero input, so a CTLZ is
  // worth keeping as one instruction; this stops CodeGenPrepare from expanding
  // it into a zero-check branch before instruction selection.
  bool isCheapToSpeculateCtlz(Type *) const override { return true; }

  // Inline assembly support. Recognizes the generic "r" register constraint
  // (any GPR) and three immediate constraints mapped to real NDS32 immediate
  // fields: "I" = signed 15-bit (addi/load-store offset), "J" = signed 20-bit
  // (movi), "K" = unsigned 15-bit (ori/andi/xori). "m" memory operands are
  // handled by the default getInlineAsmMemConstraint plus the DAG selector's
  // SelectInlineAsmMemoryOperand.
  ConstraintType getConstraintType(StringRef Constraint) const override;

  std::pair<unsigned, const TargetRegisterClass *>
  getRegForInlineAsmConstraint(const TargetRegisterInfo *TRI,
                               StringRef Constraint, MVT VT) const override;

  void LowerAsmOperandForConstraint(SDValue Op, StringRef Constraint,
                                    std::vector<SDValue> &Ops,
                                    SelectionDAG &DAG) const override;

  // This is a single-hart target (the firmware target spec sets
  // singlethread): atomics have no other observer, so lower every atomic
  // operation to its plain non-atomic equivalent.
  AtomicExpansionKind shouldExpandAtomicLoadInIR(LoadInst *) const override {
    return AtomicExpansionKind::NotAtomic;
  }
  AtomicExpansionKind shouldExpandAtomicStoreInIR(StoreInst *) const override {
    return AtomicExpansionKind::NotAtomic;
  }
  AtomicExpansionKind
  shouldExpandAtomicRMWInIR(AtomicRMWInst *) const override {
    return AtomicExpansionKind::NotAtomic;
  }
  AtomicExpansionKind
  shouldExpandAtomicCmpXchgInIR(AtomicCmpXchgInst *) const override {
    return AtomicExpansionKind::NotAtomic;
  }
};
} // namespace llvm

#endif // LLVM_LIB_TARGET_NDS32_NDS32ISELLOWERING_H
