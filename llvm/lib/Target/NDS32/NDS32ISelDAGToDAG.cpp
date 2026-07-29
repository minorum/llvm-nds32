//===-- NDS32ISelDAGToDAG.cpp - A dag to dag inst selector for NDS32 ------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "NDS32.h"
#include "NDS32TargetMachine.h"
#include "NDS32ISelLowering.h"
#include "NDS32Subtarget.h"
#include "llvm/CodeGen/SelectionDAGISel.h"
#include "llvm/CodeGen/SelectionDAGNodes.h"
#include "llvm/IR/InlineAsm.h"
#include "llvm/Support/Compiler.h"

using namespace llvm;

#define DEBUG_TYPE "nds32-isel"
#define PASS_NAME "NDS32 DAG->DAG Pattern Instruction Selection"

namespace {
class NDS32DAGToDAGISel : public SelectionDAGISel {
  // Set per function; referenced by the generated predicate code (HasFPU).
  const NDS32Subtarget *Subtarget = nullptr;

public:
  NDS32DAGToDAGISel() = delete;
  NDS32DAGToDAGISel(NDS32TargetMachine &TM, CodeGenOptLevel OptLevel)
      : SelectionDAGISel(TM, OptLevel) {}

  bool runOnMachineFunction(MachineFunction &MF) override {
    Subtarget = &MF.getSubtarget<NDS32Subtarget>();
    return SelectionDAGISel::runOnMachineFunction(MF);
  }

  bool selectMemAddr(SDValue Addr, SDValue &Base, SDValue &Offset);
  bool selectRegOffsetAddr(SDValue Addr, SDValue &Base, SDValue &Index,
                           SDValue &Scale);

  // Lower an inline-asm "m"/"o" memory operand into the backend's native
  // base+offset addressing pair, reusing selectMemAddr. The two operands are
  // printed as "[$base + off]" by NDS32AsmPrinter::PrintAsmMemoryOperand.
  bool SelectInlineAsmMemoryOperand(const SDValue &Op,
                                    InlineAsm::ConstraintCode ConstraintID,
                                    std::vector<SDValue> &OutOps) override {
    switch (ConstraintID) {
    case InlineAsm::ConstraintCode::m:
    case InlineAsm::ConstraintCode::o: {
      SDValue Base, Offset;
      selectMemAddr(Op, Base, Offset);
      OutOps.push_back(Base);
      OutOps.push_back(Offset);
      return false;
    }
    default:
      return true;
    }
  }

  bool trySelectPostInc(SDNode *Node);

  void Select(SDNode *Node) override {
    if (trySelectPostInc(Node))
      return;
    // A standalone FrameIndex value (e.g. the address of a local passed to a
    // call) materializes as "addi $dst, <fi>, 0"; eliminateFrameIndex rewrites
    // the FI/offset pair into "$sp + frameoffset".
    if (Node->getOpcode() == ISD::FrameIndex) {
      SDLoc DL(Node);
      int FI = cast<FrameIndexSDNode>(Node)->getIndex();
      SDValue TFI = CurDAG->getTargetFrameIndex(FI, MVT::i32);
      SDValue Zero = CurDAG->getTargetConstant(0, DL, MVT::i32);
      ReplaceNode(Node, CurDAG->getMachineNode(NDS32::ADDri, DL, MVT::i32, TFI,
                                               Zero));
      return;
    }
    SelectCode(Node);
  }

#include "NDS32GenDAGISel.inc"
};
} // end anonymous namespace

bool NDS32DAGToDAGISel::selectMemAddr(SDValue Addr, SDValue &Base,
                                      SDValue &Offset) {
  SDLoc DL(Addr);

  if (auto *FIN = dyn_cast<FrameIndexSDNode>(Addr)) {
    Base = CurDAG->getTargetFrameIndex(FIN->getIndex(), MVT::i32);
    Offset = CurDAG->getTargetConstant(0, DL, MVT::i32);
    return true;
  }

  if (Addr.getOpcode() == ISD::ADD) {
    SDValue LHS = Addr.getOperand(0);
    SDValue RHS = Addr.getOperand(1);

    // Only fold the constant into the memory operand's immediate when it fits
    // the instruction's signed offset field. The encoders place a 15-bit
    // (possibly scaled) value in the offset; a value that doesn't fit a signed
    // 15-bit byte offset must be materialized into the base register instead,
    // otherwise the encoding would be silently truncated.
    if (auto *CN = dyn_cast<ConstantSDNode>(RHS)) {
      int64_t Imm = CN->getSExtValue();
      if (isInt<15>(Imm)) {
        Base = LHS;
        Offset = CurDAG->getSignedTargetConstant(Imm, DL, MVT::i32);
        return true;
      }
    }

    if (auto *CN = dyn_cast<ConstantSDNode>(LHS)) {
      int64_t Imm = CN->getSExtValue();
      if (isInt<15>(Imm)) {
        Base = RHS;
        Offset = CurDAG->getSignedTargetConstant(Imm, DL, MVT::i32);
        return true;
      }
    }
  }

  Base = Addr;
  Offset = CurDAG->getTargetConstant(0, DL, MVT::i32);
  return true;
}

// Select a POST_INC indexed load or store into lwi.bi/swi.bi etc. The indexed
// load has results (value, writeback-base, chain); the indexed store has
// (writeback-base, chain). The byte increment is a constant (validated by
// getPostIndexedAddressParts).
bool NDS32DAGToDAGISel::trySelectPostInc(SDNode *Node) {
  SDLoc DL(Node);
  if (auto *LD = dyn_cast<LoadSDNode>(Node)) {
    if (LD->getAddressingMode() != ISD::POST_INC)
      return false;
    EVT MemVT = LD->getMemoryVT();
    bool Sext = LD->getExtensionType() == ISD::SEXTLOAD;
    unsigned Opc;
    if (MemVT == MVT::i32)
      Opc = NDS32::LWI_POST;
    else if (MemVT == MVT::i16)
      Opc = Sext ? NDS32::LHSI_POST : NDS32::LHI_POST;
    else if (MemVT == MVT::i8)
      Opc = Sext ? NDS32::LBSI_POST : NDS32::LBI_POST;
    else
      return false;
    int64_t Inc = cast<ConstantSDNode>(LD->getOffset())->getSExtValue();
    SDValue Imm = CurDAG->getSignedTargetConstant(Inc, DL, MVT::i32);
    SDValue Ops[] = {LD->getBasePtr(), Imm, LD->getChain()};
    SDNode *New = CurDAG->getMachineNode(
        Opc, DL, {MVT::i32, MVT::i32, MVT::Other}, Ops);
    // value, writeback base, chain
    ReplaceUses(SDValue(Node, 0), SDValue(New, 0));
    ReplaceUses(SDValue(Node, 1), SDValue(New, 1));
    ReplaceUses(SDValue(Node, 2), SDValue(New, 2));
    CurDAG->RemoveDeadNode(Node);
    return true;
  }
  if (auto *ST = dyn_cast<StoreSDNode>(Node)) {
    if (ST->getAddressingMode() != ISD::POST_INC)
      return false;
    EVT MemVT = ST->getMemoryVT();
    unsigned Opc;
    if (MemVT == MVT::i32)
      Opc = NDS32::SWI_POST;
    else if (MemVT == MVT::i16)
      Opc = NDS32::SHI_POST;
    else if (MemVT == MVT::i8)
      Opc = NDS32::SBI_POST;
    else
      return false;
    int64_t Inc = cast<ConstantSDNode>(ST->getOffset())->getSExtValue();
    SDValue Imm = CurDAG->getSignedTargetConstant(Inc, DL, MVT::i32);
    SDValue Ops[] = {ST->getValue(), ST->getBasePtr(), Imm, ST->getChain()};
    SDNode *New =
        CurDAG->getMachineNode(Opc, DL, {MVT::i32, MVT::Other}, Ops);
    // writeback base, chain
    ReplaceUses(SDValue(Node, 0), SDValue(New, 0));
    ReplaceUses(SDValue(Node, 1), SDValue(New, 1));
    CurDAG->RemoveDeadNode(Node);
    return true;
  }
  return false;
}

// Match "base + index" or "base + (index << sv)" (sv in 0..3) for the
// register-offset load/store forms (lw [$ra + $rb << sv]). A constant or
// frame-index operand is left to selectMemAddr's base+immediate form.
bool NDS32DAGToDAGISel::selectRegOffsetAddr(SDValue Addr, SDValue &Base,
                                            SDValue &Index, SDValue &Scale) {
  if (Addr.getOpcode() != ISD::ADD)
    return false;
  SDLoc DL(Addr);
  SDValue LHS = Addr.getOperand(0);
  SDValue RHS = Addr.getOperand(1);

  // A symbolic address is materialized as ADD(Wrapper(HI20), Wrapper(LO12))
  // (a global/constant-pool/jump-table/external fragment). Those Wrapper
  // operands are not runtime register values, so this ADD must lower to
  // SETHI+ADDri via its own pattern — not be folded into a reg+reg load.
  if (LHS.getOpcode() == NDS32ISD::Wrapper ||
      RHS.getOpcode() == NDS32ISD::Wrapper)
    return false;

  auto tryShift = [&](SDValue ShlSide, SDValue OtherSide) {
    if (ShlSide.getOpcode() != ISD::SHL)
      return false;
    auto *CN = dyn_cast<ConstantSDNode>(ShlSide.getOperand(1));
    if (!CN || CN->getZExtValue() > 3)
      return false;
    Base = OtherSide;
    Index = ShlSide.getOperand(0);
    Scale = CurDAG->getTargetConstant(CN->getZExtValue(), DL, MVT::i32);
    return true;
  };
  if (tryShift(RHS, LHS) || tryShift(LHS, RHS))
    return true;

  // Plain "base + index" (scale 0). Leave constant/frame-index addends to the
  // base+immediate form.
  if (isa<ConstantSDNode>(LHS) || isa<ConstantSDNode>(RHS) ||
      isa<FrameIndexSDNode>(LHS) || isa<FrameIndexSDNode>(RHS))
    return false;
  Base = LHS;
  Index = RHS;
  Scale = CurDAG->getTargetConstant(0, DL, MVT::i32);
  return true;
}

namespace {
// LLVM 22 splits SelectionDAGISel into the DAG-selector proper and a legacy
// FunctionPass wrapper (SelectionDAGISelLegacy) that owns the pass ID.
class NDS32DAGToDAGISelLegacy : public SelectionDAGISelLegacy {
public:
  static char ID;

  NDS32DAGToDAGISelLegacy(NDS32TargetMachine &TM, CodeGenOptLevel OptLevel)
      : SelectionDAGISelLegacy(
            ID, std::make_unique<NDS32DAGToDAGISel>(TM, OptLevel)) {}

  StringRef getPassName() const override { return PASS_NAME; }
};
} // end anonymous namespace

char NDS32DAGToDAGISelLegacy::ID = 0;

FunctionPass *llvm::createNDS32ISelDag(NDS32TargetMachine &TM,
                                       CodeGenOptLevel OptLevel) {
  return new NDS32DAGToDAGISelLegacy(TM, OptLevel);
}
