#include "NDS32.h"
#include "NDS32TargetMachine.h"
#include "NDS32ISelLowering.h"
#include "llvm/CodeGen/SelectionDAGISel.h"
#include "llvm/CodeGen/SelectionDAGNodes.h"
#include "llvm/Support/Compiler.h"

using namespace llvm;

#define DEBUG_TYPE "nds32-isel"
#define PASS_NAME "NDS32 DAG->DAG Pattern Instruction Selection"

namespace {
class NDS32DAGToDAGISel : public SelectionDAGISel {
public:
  NDS32DAGToDAGISel() = delete;
  NDS32DAGToDAGISel(NDS32TargetMachine &TM, CodeGenOptLevel OptLevel)
      : SelectionDAGISel(TM, OptLevel) {}

  bool selectMemAddr(SDValue Addr, SDValue &Base, SDValue &Offset);

  void Select(SDNode *Node) override {
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
