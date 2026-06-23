//===-- NDS32ISelLowering.cpp - NDS32 DAG Lowering Implementation ---------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "NDS32ISelLowering.h"
#include "NDS32.h"
#include "NDS32InstrInfo.h"
#include "NDS32Subtarget.h"
#include "llvm/CodeGen/MachineFrameInfo.h"
#include "llvm/CodeGen/MachineFunction.h"
#include "llvm/CodeGen/MachineInstrBuilder.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/CodeGen/SelectionDAG.h"
#include "llvm/Support/ErrorHandling.h"

using namespace llvm;

NDS32TargetLowering::NDS32TargetLowering(const TargetMachine &TM,
                                         const NDS32Subtarget &STI)
    : TargetLowering(TM, STI) {
  addRegisterClass(MVT::i32, &NDS32::GPRRegClass);
  setOperationAction(ISD::GlobalAddress, MVT::i32, Custom);
  setOperationAction(ISD::ExternalSymbol, MVT::i32, Custom);
  setOperationAction(ISD::ConstantPool, MVT::i32, Custom);
  setOperationAction(ISD::CALLSEQ_START, MVT::Other, Custom);
  setOperationAction(ISD::CALLSEQ_END, MVT::Other, Custom);
  setOperationAction(ISD::BR_CC, MVT::i32, Custom);
  // A BRCOND whose condition is not a foldable SETCC (e.g. the arithmetic
  // boolean produced by an expanded i64 comparison) would otherwise reach
  // ISel unselectable. Expand turns it into "BR_CC SETNE cond, 0", handled
  // by LowerBR_CC.
  setOperationAction(ISD::BRCOND, MVT::Other, Expand);
  setOperationAction(ISD::SREM, MVT::i32, Expand);
  setOperationAction(ISD::UREM, MVT::i32, Expand);
  // We only have a low-32-bit multiply (mul). The widening/high-part multiply
  // nodes default to Legal, which would let the i64 MUL expansion emit an
  // unselectable UMUL_LOHI; force them to Expand so wide multiplies become a
  // __muldi3 libcall instead.
  setOperationAction(ISD::MULHU, MVT::i32, Expand);
  setOperationAction(ISD::MULHS, MVT::i32, Expand);
  setOperationAction(ISD::UMUL_LOHI, MVT::i32, Expand);
  setOperationAction(ISD::SMUL_LOHI, MVT::i32, Expand);
  // NDS32 (as modeled here) has no bit-counting, byte-swap, rotate, or funnel
  // shift instructions; expand them into the basic ALU ops we do have. Rust
  // core uses these pervasively (e.g. align_offset, integer formatting).
  setOperationAction({ISD::CTTZ, ISD::CTLZ, ISD::CTPOP, ISD::BSWAP,
                      ISD::CTTZ_ZERO_UNDEF, ISD::CTLZ_ZERO_UNDEF},
                     MVT::i32, Expand);
  setOperationAction({ISD::ROTL, ISD::ROTR}, MVT::i32, Expand);
  setOperationAction({ISD::FSHL, ISD::FSHR}, MVT::i32, Expand);
  // Checked arithmetic (overflow-producing ops) is everywhere in Rust core;
  // expand to an arithmetic result plus an explicit overflow compare.
  setOperationAction({ISD::SADDO, ISD::UADDO, ISD::SSUBO, ISD::USUBO,
                      ISD::SMULO, ISD::UMULO},
                     MVT::i32, Expand);
  setOperationAction({ISD::UADDO_CARRY, ISD::USUBO_CARRY}, MVT::i32, Expand);
  // Min/max and abs are not native either.
  setOperationAction({ISD::SMIN, ISD::SMAX, ISD::UMIN, ISD::UMAX, ISD::ABS},
                     MVT::i32, Expand);
  // Jump tables: lower the table address like a constant pool (SETHI+ADDri),
  // expand BR_JT into "load target from table; jr target" (the brind selects
  // to the JR instruction).
  setOperationAction(ISD::JumpTable, MVT::i32, Custom);
  setOperationAction(ISD::BR_JT, MVT::Other, Expand);
  // SELECT expands to SELECT_CC, which we lower to a control-flow diamond via
  // a custom inserter. (Leaving SELECT_CC as Expand too would loop forever:
  // SELECT -> SELECT_CC -> nowhere.)
  setOperationAction(ISD::SELECT, MVT::i32, Expand);
  setOperationAction(ISD::SELECT_CC, MVT::i32, Custom);
  setOperationAction(ISD::SHL_PARTS, MVT::i32, Expand);
  setOperationAction(ISD::SRL_PARTS, MVT::i32, Expand);
  setOperationAction(ISD::SRA_PARTS, MVT::i32, Expand);
  setCondCodeAction({ISD::SETEQ, ISD::SETNE, ISD::SETGT, ISD::SETUGT, ISD::SETGE,
                     ISD::SETLE, ISD::SETUGE, ISD::SETULE},
                    MVT::i32, Custom);
  setBooleanContents(ZeroOrOneBooleanContent);
  computeRegisterProperties(STI.getRegisterInfo());
}

const char *NDS32TargetLowering::getTargetNodeName(unsigned Opcode) const {
  switch (Opcode) {
  case NDS32ISD::RET_FLAG:
    return "NDS32ISD::RET_FLAG";
  case NDS32ISD::Wrapper:
    return "NDS32ISD::Wrapper";
  case NDS32ISD::CALL:
    return "NDS32ISD::CALL";
  case NDS32ISD::BR_CC:
    return "NDS32ISD::BR_CC";
  case NDS32ISD::SELECT_CC:
    return "NDS32ISD::SELECT_CC";
  default:
    return nullptr;
  }
}

SDValue NDS32TargetLowering::LowerFormalArguments(
    SDValue Chain, CallingConv::ID CallConv, bool IsVarArg,
    const SmallVectorImpl<ISD::InputArg> &Ins, const SDLoc &DL,
    SelectionDAG &DAG, SmallVectorImpl<SDValue> &InVals) const {
  static const MCPhysReg ArgRegs[] = {NDS32::R0, NDS32::R1, NDS32::R2,
                                      NDS32::R3, NDS32::R4, NDS32::R5};

  MachineFunction &MF = DAG.getMachineFunction();
  MachineFrameInfo &MFI = MF.getFrameInfo();

  for (unsigned I = 0, E = Ins.size(); I != E; ++I) {
    const ISD::InputArg &Arg = Ins[I];
    if (Arg.VT != MVT::i32)
      report_fatal_error("NDS32 only supports i32 arguments right now");

    if (I < 6) {
      // Mark the incoming physical register as live-in and copy from the
      // resulting virtual register, so the entry block records the live-in
      // (the machine verifier rejects copying from an undefined physreg).
      Register VReg = MF.addLiveIn(ArgRegs[I], &NDS32::GPRRegClass);
      SDValue ArgValue = DAG.getCopyFromReg(Chain, DL, VReg, MVT::i32);
      Chain = ArgValue.getValue(1);
      InVals.push_back(ArgValue);
    } else {
      unsigned Offset = (I - 6) * 4;
      int FI = MFI.CreateFixedObject(4, Offset, true);
      SDValue FIPtr = DAG.getFrameIndex(FI, getPointerTy(DAG.getDataLayout()));
      SDValue LoadVal = DAG.getLoad(
          MVT::i32, DL, Chain, FIPtr,
          MachinePointerInfo::getFixedStack(MF, FI));
      Chain = LoadVal.getValue(1);
      InVals.push_back(LoadVal);
    }
  }

  return Chain;
}

SDValue NDS32TargetLowering::LowerReturn(
    SDValue Chain, CallingConv::ID CallConv, bool IsVarArg,
    const SmallVectorImpl<ISD::OutputArg> &Outs,
    const SmallVectorImpl<SDValue> &OutVals, const SDLoc &DL,
    SelectionDAG &DAG) const {
  SDValue Glue;
  SmallVector<SDValue, 4> RetOps(1, Chain);

  if (Outs.size() > 2)
    report_fatal_error("NDS32 multiple return values (>2) are not implemented yet");

  static const MCPhysReg RetRegs[] = {NDS32::R0, NDS32::R1};

  for (unsigned I = 0, E = Outs.size(); I != E; ++I) {
    const ISD::OutputArg &Out = Outs[I];
    if (Out.VT != MVT::i32)
      report_fatal_error("NDS32 only supports i32 return parts right now");

    Chain = DAG.getCopyToReg(Chain, DL, RetRegs[I], OutVals[I], Glue);
    Glue = Chain.getValue(1);
    RetOps.push_back(DAG.getRegister(RetRegs[I], MVT::i32));
  }

  RetOps[0] = Chain;
  if (Glue.getNode())
    RetOps.push_back(Glue);

  return DAG.getNode(NDS32ISD::RET_FLAG, DL, MVT::Other, RetOps);
}

bool NDS32TargetLowering::CanLowerReturn(
    CallingConv::ID CallConv, MachineFunction &MF, bool IsVarArg,
    const SmallVectorImpl<ISD::OutputArg> &Outs, LLVMContext &Context,
    const Type *RetTy) const {
  return Outs.size() <= 2;
}

SDValue NDS32TargetLowering::LowerOperation(SDValue Op, SelectionDAG &DAG) const {
  switch (Op.getOpcode()) {
  case ISD::GlobalAddress:
    return LowerGlobalAddress(Op, DAG);
  case ISD::ExternalSymbol:
    return LowerExternalSymbol(Op, DAG);
  case ISD::ConstantPool:
    return LowerConstantPool(Op, DAG);
  case ISD::JumpTable:
    return LowerJumpTable(Op, DAG);
  case ISD::BR_CC:
    return LowerBR_CC(Op, DAG);
  case ISD::SETCC:
    return LowerSETCC(Op, DAG);
  case ISD::SELECT_CC:
    return LowerSELECT_CC(Op, DAG);
  case ISD::CALLSEQ_START:
  case ISD::CALLSEQ_END:
    return Op;
  default:
    llvm_unreachable("Unexpected node to lower");
  }
}

SDValue NDS32TargetLowering::LowerGlobalAddress(SDValue Op,
                                                SelectionDAG &DAG) const {
  SDLoc DL(Op);
  const GlobalAddressSDNode *GN = cast<GlobalAddressSDNode>(Op);
  const GlobalValue *GV = GN->getGlobal();
  int64_t Offset = GN->getOffset();
  EVT PtrVT = getPointerTy(DAG.getDataLayout());

  SDValue Hi = DAG.getTargetGlobalAddress(GV, DL, PtrVT, Offset, NDS32II::MO_HI20);
  SDValue Lo = DAG.getTargetGlobalAddress(GV, DL, PtrVT, Offset, NDS32II::MO_LO12S0);

  SDValue HiNode = DAG.getNode(NDS32ISD::Wrapper, DL, PtrVT, Hi);
  // ADD(Wrapper(HI20), Wrapper(LO12S0)) → SETHI + ADDri via tablegen patterns.
  return DAG.getNode(ISD::ADD, DL, PtrVT, HiNode,
                     DAG.getNode(NDS32ISD::Wrapper, DL, PtrVT, Lo));
}

SDValue NDS32TargetLowering::LowerConstantPool(SDValue Op,
                                               SelectionDAG &DAG) const {
  SDLoc DL(Op);
  ConstantPoolSDNode *CP = cast<ConstantPoolSDNode>(Op);
  EVT PtrVT = getPointerTy(DAG.getDataLayout());

  SDValue Hi, Lo;
  if (CP->isMachineConstantPoolEntry()) {
    Hi = DAG.getTargetConstantPool(CP->getMachineCPVal(), PtrVT, CP->getAlign(),
                                   CP->getOffset(), NDS32II::MO_HI20);
    Lo = DAG.getTargetConstantPool(CP->getMachineCPVal(), PtrVT, CP->getAlign(),
                                   CP->getOffset(), NDS32II::MO_LO12S0);
  } else {
    Hi = DAG.getTargetConstantPool(CP->getConstVal(), PtrVT, CP->getAlign(),
                                   CP->getOffset(), NDS32II::MO_HI20);
    Lo = DAG.getTargetConstantPool(CP->getConstVal(), PtrVT, CP->getAlign(),
                                   CP->getOffset(), NDS32II::MO_LO12S0);
  }

  SDValue HiNode = DAG.getNode(NDS32ISD::Wrapper, DL, PtrVT, Hi);
  // ADD(Wrapper(HI20), Wrapper(LO12S0)) → SETHI + ADDri via tablegen patterns.
  return DAG.getNode(ISD::ADD, DL, PtrVT, HiNode,
                     DAG.getNode(NDS32ISD::Wrapper, DL, PtrVT, Lo));
}

SDValue NDS32TargetLowering::LowerJumpTable(SDValue Op,
                                            SelectionDAG &DAG) const {
  SDLoc DL(Op);
  JumpTableSDNode *JT = cast<JumpTableSDNode>(Op);
  EVT PtrVT = getPointerTy(DAG.getDataLayout());

  SDValue Hi = DAG.getTargetJumpTable(JT->getIndex(), PtrVT, NDS32II::MO_HI20);
  SDValue Lo = DAG.getTargetJumpTable(JT->getIndex(), PtrVT, NDS32II::MO_LO12S0);

  SDValue HiNode = DAG.getNode(NDS32ISD::Wrapper, DL, PtrVT, Hi);
  // ADD(Wrapper(HI20), Wrapper(LO12S0)) → SETHI + ADDri via tablegen patterns.
  return DAG.getNode(ISD::ADD, DL, PtrVT, HiNode,
                     DAG.getNode(NDS32ISD::Wrapper, DL, PtrVT, Lo));
}

SDValue NDS32TargetLowering::LowerExternalSymbol(SDValue Op,
                                                  SelectionDAG &DAG) const {
  SDLoc DL(Op);
  const ExternalSymbolSDNode *ES = cast<ExternalSymbolSDNode>(Op);
  EVT PtrVT = getPointerTy(DAG.getDataLayout());

  SDValue Hi = DAG.getTargetExternalSymbol(ES->getSymbol(), PtrVT, NDS32II::MO_HI20);
  SDValue Lo = DAG.getTargetExternalSymbol(ES->getSymbol(), PtrVT, NDS32II::MO_LO12S0);

  SDValue HiNode = DAG.getNode(NDS32ISD::Wrapper, DL, PtrVT, Hi);
  // ADD(Wrapper(HI20), Wrapper(LO12S0)) → SETHI + ADDri via tablegen patterns.
  return DAG.getNode(ISD::ADD, DL, PtrVT, HiNode,
                     DAG.getNode(NDS32ISD::Wrapper, DL, PtrVT, Lo));
}

SDValue NDS32TargetLowering::LowerCall(TargetLowering::CallLoweringInfo &CLI,
                                       SmallVectorImpl<SDValue> &InVals) const {
  SelectionDAG &DAG                     = CLI.DAG;
  SDLoc &DL                             = CLI.DL;
  SmallVectorImpl<ISD::OutputArg> &Outs = CLI.Outs;
  SmallVectorImpl<SDValue> &OutVals     = CLI.OutVals;
  SmallVectorImpl<ISD::InputArg> &Ins   = CLI.Ins;
  SDValue Chain                         = CLI.Chain;
  SDValue Callee                        = CLI.Callee;
  bool &IsTailCall                      = CLI.IsTailCall;
  CallingConv::ID CallConv              = CLI.CallConv;
  bool IsVarArg                         = CLI.IsVarArg;

  IsTailCall = false;

  static const MCPhysReg ArgRegs[] = {NDS32::R0, NDS32::R1, NDS32::R2,
                                      NDS32::R3, NDS32::R4, NDS32::R5};

  unsigned NumStackArgs = Outs.size() > 6 ? Outs.size() - 6 : 0;
  unsigned NumBytes = NumStackArgs * 4;
  Chain = DAG.getCALLSEQ_START(Chain, NumBytes, 0, DL);

  SmallVector<std::pair<unsigned, SDValue>, 4> RegsToPass;
  SmallVector<std::pair<unsigned, SDValue>, 4> MemToPass;
  SmallVector<SDValue, 4> MemOpChains;
  for (unsigned I = 0, E = Outs.size(); I != E; ++I) {
    SDValue Arg = OutVals[I];
    if (I < 6) {
      RegsToPass.push_back(std::make_pair(ArgRegs[I], Arg));
    } else {
      MemToPass.push_back(std::make_pair((I - 6) * 4, Arg));
    }
  }

  if (!MemToPass.empty()) {
    SDValue StackPtr = DAG.getCopyFromReg(Chain, DL, NDS32::R31, MVT::i32);
    for (unsigned I = 0, E = MemToPass.size(); I != E; ++I) {
      unsigned Offset = MemToPass[I].first;
      SDValue ArgVal = MemToPass[I].second;
      SDValue Address = DAG.getNode(ISD::ADD, DL, MVT::i32, StackPtr,
                                    DAG.getIntPtrConstant(Offset, DL));
      MemOpChains.push_back(
          DAG.getStore(Chain, DL, ArgVal, Address, MachinePointerInfo()));
    }
  }

  if (!MemOpChains.empty())
    Chain = DAG.getNode(ISD::TokenFactor, DL, MVT::Other, MemOpChains);

  SDValue InGlue;
  for (unsigned I = 0, E = RegsToPass.size(); I != E; ++I) {
    Chain = DAG.getCopyToReg(Chain, DL, RegsToPass[I].first,
                             RegsToPass[I].second, InGlue);
    InGlue = Chain.getValue(1);
  }

  if (GlobalAddressSDNode *G = dyn_cast<GlobalAddressSDNode>(Callee)) {
    Callee = DAG.getTargetGlobalAddress(G->getGlobal(), DL, MVT::i32, 0, NDS32II::MO_NO_FLAG);
  } else if (ExternalSymbolSDNode *E = dyn_cast<ExternalSymbolSDNode>(Callee)) {
    Callee = DAG.getTargetExternalSymbol(E->getSymbol(), MVT::i32, NDS32II::MO_NO_FLAG);
  }

  SDVTList NodeTys = DAG.getVTList(MVT::Other, MVT::Glue);
  SmallVector<SDValue, 8> Ops;
  Ops.push_back(Chain);
  Ops.push_back(Callee);

  for (unsigned I = 0, E = RegsToPass.size(); I != E; ++I)
    Ops.push_back(DAG.getRegister(RegsToPass[I].first,
                                  RegsToPass[I].second.getValueType()));

  // Add a register mask operand representing the call-preserved registers.
  const TargetRegisterInfo *TRI = DAG.getSubtarget().getRegisterInfo();
  const uint32_t *Mask = TRI->getCallPreservedMask(DAG.getMachineFunction(), CallConv);
  assert(Mask && "Missing call preserved mask for NDS32");
  Ops.push_back(DAG.getRegisterMask(Mask));

  if (InGlue.getNode())
    Ops.push_back(InGlue);

  Chain = DAG.getNode(NDS32ISD::CALL, DL, NodeTys, Ops);
  InGlue = Chain.getValue(1);

  Chain = DAG.getCALLSEQ_END(Chain, NumBytes, 0, InGlue, DL);
  InGlue = Chain.getValue(1);

  return LowerCallResult(Chain, InGlue, CallConv, IsVarArg, Ins, DL, DAG, InVals);
}

SDValue NDS32TargetLowering::LowerCallResult(
    SDValue Chain, SDValue InGlue, CallingConv::ID CallConv, bool IsVarArg,
    const SmallVectorImpl<ISD::InputArg> &Ins, const SDLoc &DL,
    SelectionDAG &DAG, SmallVectorImpl<SDValue> &InVals) const {

  if (Ins.size() > 2)
    report_fatal_error("NDS32 multiple return values (>2) are not implemented yet");

  static const MCPhysReg RetRegs[] = {NDS32::R0, NDS32::R1};

  for (unsigned I = 0, E = Ins.size(); I != E; ++I) {
    const ISD::InputArg &In = Ins[I];
    if (In.VT != MVT::i32)
      report_fatal_error("NDS32 only supports i32 return parts right now");

    SDValue Val = DAG.getCopyFromReg(Chain, DL, RetRegs[I], MVT::i32, InGlue);
    Chain = Val.getValue(1);
    InGlue = Val.getValue(2);
    InVals.push_back(Val);
  }

  return Chain;
}

SDValue NDS32TargetLowering::LowerBR_CC(SDValue Op, SelectionDAG &DAG) const {
  SDValue Chain = Op.getOperand(0);
  ISD::CondCode CC = cast<CondCodeSDNode>(Op.getOperand(1))->get();
  SDValue LHS = Op.getOperand(2);
  SDValue RHS = Op.getOperand(3);
  SDValue Dest = Op.getOperand(4);
  SDLoc DL(Op);

  bool CompareZero = false;
  if (ConstantSDNode *C = dyn_cast<ConstantSDNode>(RHS)) {
    if (C->getZExtValue() == 0) {
      CompareZero = true;
    }
  }

  // Normalize comparison against constants to 0 if possible
  if (auto *C = dyn_cast<ConstantSDNode>(RHS)) {
    int64_t Val = C->getSExtValue();
    bool Changed = false;
    ISD::CondCode NewCC = CC;
    int64_t NewVal = Val;

    if (Val == -1) {
      if (CC == ISD::SETGT) {
        NewCC = ISD::SETGE;
        NewVal = 0;
        Changed = true;
      } else if (CC == ISD::SETLE) {
        NewCC = ISD::SETLT;
        NewVal = 0;
        Changed = true;
      }
    } else if (Val == 1) {
      if (CC == ISD::SETLT) {
        NewCC = ISD::SETLE;
        NewVal = 0;
        Changed = true;
      } else if (CC == ISD::SETGE) {
        NewCC = ISD::SETGT;
        NewVal = 0;
        Changed = true;
      } else if (CC == ISD::SETUGE) {
        NewCC = ISD::SETUGT;
        NewVal = 0;
        Changed = true;
      } else if (CC == ISD::SETULT) {
        NewCC = ISD::SETEQ;
        NewVal = 0;
        Changed = true;
      }
    } else if (Val == 0) {
      if (CC == ISD::SETULE) {
        NewCC = ISD::SETEQ;
        NewVal = 0;
        Changed = true;
      }
    }

    if (Changed) {
      CC = NewCC;
      RHS = DAG.getConstant(NewVal, DL, RHS.getValueType());
      CompareZero = true;
    }
  }

  // Optimize branch on comparison result against 0:
  // e.g. BR_CC SETNE, (SETCC LHS', RHS', CC'), 0, Dest -> BR_CC CC', LHS', RHS', Dest
  if (CompareZero && (CC == ISD::SETEQ || CC == ISD::SETNE)) {
    SDValue Cond = LHS;
    ISD::CondCode BranchCC = CC;

    while (true) {
      if (Cond.getOpcode() == ISD::ZERO_EXTEND ||
          Cond.getOpcode() == ISD::ANY_EXTEND ||
          Cond.getOpcode() == ISD::SIGN_EXTEND) {
        Cond = Cond.getOperand(0);
        continue;
      }
      if (Cond.getOpcode() == ISD::XOR && isa<ConstantSDNode>(Cond.getOperand(1))) {
        if (cast<ConstantSDNode>(Cond.getOperand(1))->getZExtValue() == 1) {
          Cond = Cond.getOperand(0);
          BranchCC = ISD::getSetCCInverse(BranchCC, MVT::i32);
          continue;
        }
      }
      break;
    }

    if (Cond.getOpcode() == ISD::SETCC) {
      SDValue NewLHS = Cond.getOperand(0);
      SDValue NewRHS = Cond.getOperand(1);
      ISD::CondCode InnerCC = cast<CondCodeSDNode>(Cond.getOperand(2))->get();

      if (BranchCC == ISD::SETEQ)
        InnerCC = ISD::getSetCCInverse(InnerCC, MVT::i32);

      bool NewCompareZero = false;
      if (ConstantSDNode *C = dyn_cast<ConstantSDNode>(NewRHS)) {
        if (C->getZExtValue() == 0) {
          NewCompareZero = true;
        }
      }

      bool DirectBranchLegal = false;
      if (NewCompareZero) {
        switch (InnerCC) {
        case ISD::SETEQ:
        case ISD::SETNE:
        case ISD::SETLT:
        case ISD::SETGE:
        case ISD::SETGT:
        case ISD::SETLE:
        case ISD::SETULT:
        case ISD::SETUGE:
        case ISD::SETUGT:
        case ISD::SETULE:
          DirectBranchLegal = true;
          break;
        default:
          break;
        }
      } else {
        switch (InnerCC) {
        case ISD::SETEQ:
        case ISD::SETNE:
          DirectBranchLegal = true;
          break;
        default:
          break;
        }
      }

      if (DirectBranchLegal) {
        return DAG.getNode(NDS32ISD::BR_CC, DL, MVT::Other, Chain,
                           DAG.getCondCode(InnerCC), NewLHS, NewRHS, Dest);
      }
    }
  }

  bool Legal = false;
  if (CompareZero) {
    switch (CC) {
    case ISD::SETEQ:
    case ISD::SETNE:
    case ISD::SETLT:
    case ISD::SETGE:
    case ISD::SETGT:
    case ISD::SETLE:
      Legal = true;
      break;
    default:
      break;
    }
  } else {
    switch (CC) {
    case ISD::SETEQ:
    case ISD::SETNE:
      Legal = true;
      break;
    default:
      break;
    }
  }

  if (Legal) {
    return DAG.getNode(NDS32ISD::BR_CC, DL, MVT::Other, Chain,
                       DAG.getCondCode(CC), LHS, RHS, Dest);
  }

  ISD::CondCode TargetCC;
  ISD::CondCode BranchCC;
  bool SwapOps = false;

  switch (CC) {
  case ISD::SETLT:
    TargetCC = ISD::SETLT;
    BranchCC = ISD::SETNE;
    break;
  case ISD::SETULT:
    TargetCC = ISD::SETULT;
    BranchCC = ISD::SETNE;
    break;
  case ISD::SETGE:
    TargetCC = ISD::SETLT;
    BranchCC = ISD::SETEQ;
    break;
  case ISD::SETUGE:
    TargetCC = ISD::SETULT;
    BranchCC = ISD::SETEQ;
    break;
  case ISD::SETGT:
    TargetCC = ISD::SETLT;
    BranchCC = ISD::SETNE;
    SwapOps = true;
    break;
  case ISD::SETUGT:
    TargetCC = ISD::SETULT;
    BranchCC = ISD::SETNE;
    SwapOps = true;
    break;
  case ISD::SETLE:
    TargetCC = ISD::SETLT;
    BranchCC = ISD::SETEQ;
    SwapOps = true;
    break;
  case ISD::SETULE:
    TargetCC = ISD::SETULT;
    BranchCC = ISD::SETEQ;
    SwapOps = true;
    break;
  default:
    llvm_unreachable("Unexpected condition code for register branch!");
  }

  SDValue Op0 = SwapOps ? RHS : LHS;
  SDValue Op1 = SwapOps ? LHS : RHS;

  SDValue Target = DAG.getNode(ISD::SETCC, DL, MVT::i32, Op0, Op1,
                              DAG.getCondCode(TargetCC));
  return DAG.getNode(NDS32ISD::BR_CC, DL, MVT::Other, Chain,
                     DAG.getCondCode(BranchCC), Target,
                     DAG.getConstant(0, DL, MVT::i32), Dest);
}

SDValue NDS32TargetLowering::LowerSETCC(SDValue Op, SelectionDAG &DAG) const {
  MVT OpVT = Op.getOperand(0).getSimpleValueType();
  assert(OpVT.isScalarInteger() && "Only scalar integer SETCC is custom lowered");
  MVT VT = Op.getSimpleValueType();
  SDValue LHS = Op.getOperand(0);
  SDValue RHS = Op.getOperand(1);
  ISD::CondCode CCVal = cast<CondCodeSDNode>(Op.getOperand(2))->get();
  SDLoc DL(Op);

  // The hardware only provides "set if less than" in signed (slts -> SETLT)
  // and unsigned (slt -> SETULT) forms. Every other integer predicate is
  // rewritten in terms of those, optionally inverting the 0/1 boolean result
  // with XOR 1 (valid because setBooleanContents is ZeroOrOneBooleanContent).
  switch (CCVal) {
  default:
    // SETLT / SETULT are already legal and never reach here.
    return SDValue();
  case ISD::SETGT:
  case ISD::SETUGT: {
    // x > y  <=>  y < x
    ISD::CondCode LtCC = (CCVal == ISD::SETUGT) ? ISD::SETULT : ISD::SETLT;
    return DAG.getSetCC(DL, VT, RHS, LHS, LtCC);
  }
  case ISD::SETGE:
  case ISD::SETUGE: {
    // x >= y  <=>  !(x < y)
    ISD::CondCode LtCC = (CCVal == ISD::SETUGE) ? ISD::SETULT : ISD::SETLT;
    SDValue Lt = DAG.getSetCC(DL, VT, LHS, RHS, LtCC);
    return DAG.getNode(ISD::XOR, DL, VT, Lt, DAG.getConstant(1, DL, VT));
  }
  case ISD::SETLE:
  case ISD::SETULE: {
    // x <= y  <=>  !(y < x)
    ISD::CondCode LtCC = (CCVal == ISD::SETULE) ? ISD::SETULT : ISD::SETLT;
    SDValue Lt = DAG.getSetCC(DL, VT, RHS, LHS, LtCC);
    return DAG.getNode(ISD::XOR, DL, VT, Lt, DAG.getConstant(1, DL, VT));
  }
  case ISD::SETEQ:
  case ISD::SETNE: {
    // x != y  <=>  0 <u (x ^ y)   (the xor is nonzero exactly when unequal);
    // x == y is the inverse of that. Build equality on top of the SETNE form
    // rather than as "(x ^ y) <u 1": the latter is canonicalized back to
    // SETEQ by the DAG combiner, which ping-pongs with this custom lowering.
    SDValue Xor = DAG.getNode(ISD::XOR, DL, OpVT, LHS, RHS);
    SDValue Ne =
        DAG.getSetCC(DL, VT, DAG.getConstant(0, DL, OpVT), Xor, ISD::SETULT);
    if (CCVal == ISD::SETNE)
      return Ne;
    return DAG.getNode(ISD::XOR, DL, VT, Ne, DAG.getConstant(1, DL, VT));
  }
  }
}

SDValue NDS32TargetLowering::LowerSELECT_CC(SDValue Op,
                                            SelectionDAG &DAG) const {
  SDValue LHS = Op.getOperand(0);
  SDValue RHS = Op.getOperand(1);
  SDValue TrueV = Op.getOperand(2);
  SDValue FalseV = Op.getOperand(3);
  ISD::CondCode CC = cast<CondCodeSDNode>(Op.getOperand(4))->get();
  SDLoc DL(Op);

  // Reduce the comparison to a single i32 boolean (0/1) and let the Select
  // pseudo branch on "boolean != 0". The common case produced by expanding
  // ISD::SELECT is "(SELECT_CC cond, 0, T, F, SETNE)", where cond is already
  // the 0/1 value we want to test, so skip the redundant compare.
  SDValue Cond;
  if (CC == ISD::SETNE && isNullConstant(RHS))
    Cond = LHS;
  else
    Cond = DAG.getSetCC(DL, MVT::i32, LHS, RHS, CC);

  return DAG.getNode(NDS32ISD::SELECT_CC, DL, Op.getValueType(), Cond, TrueV,
                     FalseV);
}

MachineBasicBlock *
NDS32TargetLowering::EmitInstrWithCustomInserter(MachineInstr &MI,
                                                 MachineBasicBlock *BB) const {
  assert(MI.getOpcode() == NDS32::Select &&
         "Unexpected instruction for custom inserter");

  const TargetInstrInfo &TII = *BB->getParent()->getSubtarget().getInstrInfo();
  const DebugLoc &DL = MI.getDebugLoc();
  const BasicBlock *LLVMBB = BB->getBasicBlock();
  MachineFunction *MF = BB->getParent();
  MachineFunction::iterator It = ++BB->getIterator();

  // Build the diamond:
  //
  //   ThisMBB:
  //     bnez $cond, SinkMBB     ; cond != 0 -> take the true value
  //     (fall through to Copy0MBB)
  //   Copy0MBB:
  //     (fall through to SinkMBB)
  //   SinkMBB:
  //     $dst = PHI [$t, ThisMBB], [$f, Copy0MBB]
  MachineBasicBlock *ThisMBB = BB;
  MachineBasicBlock *Copy0MBB = MF->CreateMachineBasicBlock(LLVMBB);
  MachineBasicBlock *SinkMBB = MF->CreateMachineBasicBlock(LLVMBB);
  MF->insert(It, Copy0MBB);
  MF->insert(It, SinkMBB);

  // Move everything after the Select to SinkMBB and inherit ThisMBB's
  // successors.
  SinkMBB->splice(SinkMBB->begin(), ThisMBB,
                  std::next(MachineBasicBlock::iterator(MI)), ThisMBB->end());
  SinkMBB->transferSuccessorsAndUpdatePHIs(ThisMBB);

  ThisMBB->addSuccessor(Copy0MBB);
  ThisMBB->addSuccessor(SinkMBB);

  Register DstReg = MI.getOperand(0).getReg();
  Register CondReg = MI.getOperand(1).getReg();
  Register TrueReg = MI.getOperand(2).getReg();
  Register FalseReg = MI.getOperand(3).getReg();

  BuildMI(ThisMBB, DL, TII.get(NDS32::BNEZ)).addReg(CondReg).addMBB(SinkMBB);

  Copy0MBB->addSuccessor(SinkMBB);

  BuildMI(*SinkMBB, SinkMBB->begin(), DL, TII.get(TargetOpcode::PHI), DstReg)
      .addReg(TrueReg)
      .addMBB(ThisMBB)
      .addReg(FalseReg)
      .addMBB(Copy0MBB);

  MI.eraseFromParent();
  return SinkMBB;
}
