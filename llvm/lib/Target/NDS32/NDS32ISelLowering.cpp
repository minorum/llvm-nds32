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
#include "NDS32MachineFunctionInfo.h"
#include "NDS32Subtarget.h"
#include "llvm/CodeGen/CallingConvLower.h"
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
  // We have native clz (CTLZ, including the zero-undef form) and form a 32-bit
  // byte reverse from wsbh+rotri (BSWAP) — see NDS32InstrInfo.td. The remaining
  // bit-counting ops have no instruction; expand them into the basic ALU ops we
  // do have. Rust core uses these pervasively (e.g. align_offset, formatting).
  // Native clz handles a zero input (clz(0) = 32), matching both the
  // zero-defined and zero-undef forms. isCheapToSpeculateCtlz() (below) keeps
  // CodeGenPrepare from despeculating CTLZ into a zero-check branch first.
  setOperationAction({ISD::CTLZ, ISD::CTLZ_ZERO_UNDEF, ISD::BSWAP}, MVT::i32,
                     Legal);
  setOperationAction({ISD::CTTZ, ISD::CTPOP, ISD::CTTZ_ZERO_UNDEF}, MVT::i32,
                     Expand);
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
  // Dynamic alloca: adjust $sp by the (aligned) size and return the new $sp.
  setOperationAction(ISD::DYNAMIC_STACKALLOC, MVT::i32, Custom);
  // Frame/return address builtins.
  setOperationAction(ISD::FRAMEADDR, MVT::i32, Custom);
  setOperationAction(ISD::RETURNADDR, MVT::i32, Custom);
  // Varargs: VASTART stores the save-area address; the rest expand against the
  // char* va_list.
  setOperationAction(ISD::VASTART, MVT::Other, Custom);
  setOperationAction({ISD::VAARG, ISD::VACOPY, ISD::VAEND}, MVT::Other, Expand);
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

// NDS32 ABI2 argument registers, in order.
static const MCPhysReg GPRArgRegs[] = {NDS32::R0, NDS32::R1, NDS32::R2,
                                       NDS32::R3, NDS32::R4, NDS32::R5};

// Set LocVT/LocInfo for an i1/i8/i16 value promoted to i32. Returns true if a
// promotion was applied.
static void promoteToI32(MVT &LocVT, CCValAssign::LocInfo &LocInfo,
                         ISD::ArgFlagsTy ArgFlags) {
  if (LocVT != MVT::i1 && LocVT != MVT::i8 && LocVT != MVT::i16)
    return;
  LocVT = MVT::i32;
  if (ArgFlags.isSExt())
    LocInfo = CCValAssign::SExt;
  else if (ArgFlags.isZExt())
    LocInfo = CCValAssign::ZExt;
  else
    LocInfo = CCValAssign::AExt;
}

// Argument calling convention. i32/pointers go in $r0-$r5 then 4-byte stack
// slots. i64/f64 arrive pre-split into two i32 parts and are placed in an
// EVEN-aligned register pair (consuming an odd register as padding) or an
// 8-byte-aligned stack pair, per the Andes ABI2.
static bool CC_NDS32(unsigned ValNo, MVT ValVT, MVT LocVT,
                     CCValAssign::LocInfo LocInfo, ISD::ArgFlagsTy ArgFlags,
                     Type *OrigTy, CCState &State) {
  promoteToI32(LocVT, LocInfo, ArgFlags);

  SmallVectorImpl<CCValAssign> &Pending = State.getPendingLocs();

  // First half of a split i64/f64: stash it; allocate the whole pair atomically
  // when the second (end) half arrives so even-alignment is decided as a unit.
  if (ArgFlags.isSplit() && !ArgFlags.isSplitEnd()) {
    Pending.push_back(CCValAssign::getPending(ValNo, ValVT, LocVT, LocInfo));
    return false;
  }

  if (ArgFlags.isSplitEnd() && !Pending.empty()) {
    CCValAssign First = Pending.pop_back_val();
    MCRegister FirstReg = State.AllocateReg(GPRArgRegs);
    if (FirstReg.isValid()) {
      // R0..R5 are contiguous in the generated register enum.
      if ((FirstReg.id() - NDS32::R0) & 1u)    // odd -> pad, take next (even)
        FirstReg = State.AllocateReg(GPRArgRegs);
      MCRegister SecondReg;
      if (FirstReg.isValid())
        SecondReg = State.AllocateReg(GPRArgRegs);
      if (FirstReg.isValid() && SecondReg.isValid()) {
        State.addLoc(CCValAssign::getReg(First.getValNo(), First.getValVT(),
                                         FirstReg, First.getLocVT(),
                                         First.getLocInfo()));
        State.addLoc(CCValAssign::getReg(ValNo, ValVT, SecondReg, LocVT,
                                         LocInfo));
        return false;
      }
    }
    // Ran out of registers mid-pair: the whole i64 goes on the 8-byte-aligned
    // stack (no register/stack split for i64), matching Andes GCC.
    unsigned Off = State.AllocateStack(8, Align(8));
    State.addLoc(CCValAssign::getMem(First.getValNo(), First.getValVT(), Off,
                                     First.getLocVT(), First.getLocInfo()));
    State.addLoc(CCValAssign::getMem(ValNo, ValVT, Off + 4, LocVT, LocInfo));
    return false;
  }

  // Plain i32 / coerced struct word.
  if (unsigned Reg = State.AllocateReg(GPRArgRegs)) {
    State.addLoc(CCValAssign::getReg(ValNo, ValVT, Reg, LocVT, LocInfo));
    return false;
  }
  unsigned Off = State.AllocateStack(4, Align(4));
  State.addLoc(CCValAssign::getMem(ValNo, ValVT, Off, LocVT, LocInfo));
  return false;
}

// Return calling convention: up to two words in $r0:$r1 (i64 high in $r0).
static bool RetCC_NDS32(unsigned ValNo, MVT ValVT, MVT LocVT,
                        CCValAssign::LocInfo LocInfo, ISD::ArgFlagsTy ArgFlags,
                        Type *OrigTy, CCState &State) {
  promoteToI32(LocVT, LocInfo, ArgFlags);
  static const MCPhysReg RetRegs[] = {NDS32::R0, NDS32::R1};
  if (unsigned Reg = State.AllocateReg(RetRegs)) {
    State.addLoc(CCValAssign::getReg(ValNo, ValVT, Reg, LocVT, LocInfo));
    return false;
  }
  return true; // does not fit in the return registers
}

// Reconstruct the original-typed value from a register/stack location value
// (truncating a value that the CC promoted to i32).
static SDValue convertLocToVal(SelectionDAG &DAG, const SDLoc &DL,
                               const CCValAssign &VA, SDValue Val) {
  switch (VA.getLocInfo()) {
  case CCValAssign::BCvt:
    return DAG.getNode(ISD::BITCAST, DL, VA.getValVT(), Val);
  case CCValAssign::SExt:
  case CCValAssign::ZExt:
  case CCValAssign::AExt:
    if (VA.getValVT() != VA.getLocVT())
      return DAG.getNode(ISD::TRUNCATE, DL, VA.getValVT(), Val);
    return Val;
  default:
    return Val;
  }
}

// Extend/bitcast an original-typed value up to its register/stack location type.
static SDValue convertValToLoc(SelectionDAG &DAG, const SDLoc &DL,
                               const CCValAssign &VA, SDValue Val) {
  switch (VA.getLocInfo()) {
  case CCValAssign::SExt:
    return DAG.getNode(ISD::SIGN_EXTEND, DL, VA.getLocVT(), Val);
  case CCValAssign::ZExt:
    return DAG.getNode(ISD::ZERO_EXTEND, DL, VA.getLocVT(), Val);
  case CCValAssign::AExt:
    return DAG.getNode(ISD::ANY_EXTEND, DL, VA.getLocVT(), Val);
  case CCValAssign::BCvt:
    return DAG.getNode(ISD::BITCAST, DL, VA.getLocVT(), Val);
  default:
    return Val;
  }
}

SDValue NDS32TargetLowering::LowerFormalArguments(
    SDValue Chain, CallingConv::ID CallConv, bool IsVarArg,
    const SmallVectorImpl<ISD::InputArg> &Ins, const SDLoc &DL,
    SelectionDAG &DAG, SmallVectorImpl<SDValue> &InVals) const {
  MachineFunction &MF = DAG.getMachineFunction();
  MachineFrameInfo &MFI = MF.getFrameInfo();
  EVT PtrVT = getPointerTy(DAG.getDataLayout());

  SmallVector<CCValAssign, 16> ArgLocs;
  CCState CCInfo(CallConv, IsVarArg, MF, ArgLocs, *DAG.getContext());
  CCInfo.AnalyzeFormalArguments(Ins, CC_NDS32);

  for (CCValAssign &VA : ArgLocs) {
    SDValue ArgVal;
    if (VA.isRegLoc()) {
      // Mark the incoming physical register live-in and copy from the resulting
      // vreg (the machine verifier rejects copying from an undefined physreg).
      Register VReg = MF.addLiveIn(VA.getLocReg(), &NDS32::GPRRegClass);
      ArgVal = DAG.getCopyFromReg(Chain, DL, VReg, VA.getLocVT());
    } else {
      int FI = MFI.CreateFixedObject(VA.getLocVT().getStoreSize(),
                                     VA.getLocMemOffset(), /*IsImmutable=*/true);
      SDValue FIN = DAG.getFrameIndex(FI, PtrVT);
      ArgVal = DAG.getLoad(VA.getLocVT(), DL, Chain, FIN,
                           MachinePointerInfo::getFixedStack(MF, FI));
    }
    Chain = ArgVal.getValue(1);
    InVals.push_back(convertLocToVal(DAG, DL, VA, ArgVal));
  }

  if (IsVarArg) {
    // Spill the argument registers not consumed by named arguments into a save
    // area placed immediately below the incoming stack-argument area (negative
    // offsets), so register- and stack-passed variadic arguments form one
    // contiguous block that va_arg can walk. va_list (a char*) starts at the
    // first unnamed argument.
    auto *FuncInfo = MF.getInfo<NDS32MachineFunctionInfo>();
    unsigned NumGPRs = std::size(GPRArgRegs);
    unsigned Idx = CCInfo.getFirstUnallocated(GPRArgRegs);

    int FirstFI;
    if (Idx == NumGPRs) {
      // All argument registers were used by named arguments; the first variadic
      // argument is the next incoming stack slot.
      FirstFI = MFI.CreateFixedObject(4, CCInfo.getStackSize(),
                                      /*IsImmutable=*/true);
    } else {
      SmallVector<SDValue, 6> Stores;
      FirstFI = 0;
      for (unsigned I = Idx; I < NumGPRs; ++I) {
        int Off = -static_cast<int>((NumGPRs - I) * 4);
        int FI = MFI.CreateFixedObject(4, Off, /*IsImmutable=*/true);
        if (I == Idx)
          FirstFI = FI;
        Register VReg = MF.addLiveIn(GPRArgRegs[I], &NDS32::GPRRegClass);
        SDValue Val = DAG.getCopyFromReg(Chain, DL, VReg, MVT::i32);
        SDValue Addr = DAG.getFrameIndex(FI, PtrVT);
        Stores.push_back(DAG.getStore(
            Chain, DL, Val, Addr, MachinePointerInfo::getFixedStack(MF, FI)));
      }
      if (!Stores.empty())
        Chain = DAG.getNode(ISD::TokenFactor, DL, MVT::Other, Stores);
    }
    FuncInfo->setVarArgsFrameIndex(FirstFI);
  }

  return Chain;
}

SDValue NDS32TargetLowering::LowerReturn(
    SDValue Chain, CallingConv::ID CallConv, bool IsVarArg,
    const SmallVectorImpl<ISD::OutputArg> &Outs,
    const SmallVectorImpl<SDValue> &OutVals, const SDLoc &DL,
    SelectionDAG &DAG) const {
  SmallVector<CCValAssign, 4> RVLocs;
  CCState CCInfo(CallConv, IsVarArg, DAG.getMachineFunction(), RVLocs,
                 *DAG.getContext());
  CCInfo.AnalyzeReturn(Outs, RetCC_NDS32);

  SDValue Glue;
  SmallVector<SDValue, 4> RetOps(1, Chain);
  for (unsigned I = 0, E = RVLocs.size(); I != E; ++I) {
    CCValAssign &VA = RVLocs[I];
    SDValue Val = convertValToLoc(DAG, DL, VA, OutVals[I]);
    Chain = DAG.getCopyToReg(Chain, DL, VA.getLocReg(), Val, Glue);
    Glue = Chain.getValue(1);
    RetOps.push_back(DAG.getRegister(VA.getLocReg(), VA.getLocVT()));
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
  SmallVector<CCValAssign, 4> RVLocs;
  CCState CCInfo(CallConv, IsVarArg, MF, RVLocs, Context);
  return CCInfo.CheckReturn(Outs, RetCC_NDS32);
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
  case ISD::DYNAMIC_STACKALLOC:
    return LowerDYNAMIC_STACKALLOC(Op, DAG);
  case ISD::FRAMEADDR:
    return LowerFRAMEADDR(Op, DAG);
  case ISD::RETURNADDR:
    return LowerRETURNADDR(Op, DAG);
  case ISD::VASTART:
    return LowerVASTART(Op, DAG);
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

  MachineFunction &MF = DAG.getMachineFunction();
  EVT PtrVT = getPointerTy(DAG.getDataLayout());

  SmallVector<CCValAssign, 16> ArgLocs;
  CCState CCInfo(CallConv, IsVarArg, MF, ArgLocs, *DAG.getContext());
  CCInfo.AnalyzeCallOperands(Outs, CC_NDS32);
  unsigned NumBytes = alignTo(CCInfo.getStackSize(), 8);
  Chain = DAG.getCALLSEQ_START(Chain, NumBytes, 0, DL);

  SmallVector<std::pair<unsigned, SDValue>, 8> RegsToPass;
  SmallVector<SDValue, 8> MemOpChains;
  SDValue StackPtr;
  for (unsigned I = 0, E = ArgLocs.size(); I != E; ++I) {
    CCValAssign &VA = ArgLocs[I];
    SDValue Arg = convertValToLoc(DAG, DL, VA, OutVals[I]);
    if (VA.isRegLoc()) {
      RegsToPass.push_back(std::make_pair(VA.getLocReg(), Arg));
    } else {
      if (!StackPtr.getNode())
        StackPtr = DAG.getCopyFromReg(Chain, DL, NDS32::R31, PtrVT);
      SDValue Address = DAG.getNode(ISD::ADD, DL, PtrVT, StackPtr,
                                    DAG.getIntPtrConstant(VA.getLocMemOffset(), DL));
      MemOpChains.push_back(
          DAG.getStore(Chain, DL, Arg, Address, MachinePointerInfo()));
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

  SmallVector<CCValAssign, 4> RVLocs;
  CCState CCInfo(CallConv, IsVarArg, DAG.getMachineFunction(), RVLocs,
                 *DAG.getContext());
  CCInfo.AnalyzeCallResult(Ins, RetCC_NDS32);

  for (unsigned I = 0, E = RVLocs.size(); I != E; ++I) {
    CCValAssign &VA = RVLocs[I];
    SDValue Val =
        DAG.getCopyFromReg(Chain, DL, VA.getLocReg(), VA.getLocVT(), InGlue);
    Chain = Val.getValue(1);
    InGlue = Val.getValue(2);
    InVals.push_back(convertLocToVal(DAG, DL, VA, Val));
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

SDValue NDS32TargetLowering::LowerVASTART(SDValue Op, SelectionDAG &DAG) const {
  MachineFunction &MF = DAG.getMachineFunction();
  auto *FuncInfo = MF.getInfo<NDS32MachineFunctionInfo>();
  SDLoc DL(Op);
  EVT PtrVT = getPointerTy(DAG.getDataLayout());
  // Store the address of the first variadic argument into the va_list object.
  SDValue FR = DAG.getFrameIndex(FuncInfo->getVarArgsFrameIndex(), PtrVT);
  const Value *SV = cast<SrcValueSDNode>(Op.getOperand(2))->getValue();
  return DAG.getStore(Op.getOperand(0), DL, FR, Op.getOperand(1),
                      MachinePointerInfo(SV));
}

SDValue NDS32TargetLowering::LowerFRAMEADDR(SDValue Op,
                                            SelectionDAG &DAG) const {
  MachineFunction &MF = DAG.getMachineFunction();
  MF.getFrameInfo().setFrameAddressIsTaken(true);
  SDLoc DL(Op);
  EVT VT = Op.getValueType();
  // The frame pointer ($r28) is the address of the current frame.
  if (Op.getConstantOperandVal(0) != 0)
    report_fatal_error("NDS32 frameaddress only supports a depth of 0");
  return DAG.getCopyFromReg(DAG.getEntryNode(), DL, NDS32::R28, VT);
}

SDValue NDS32TargetLowering::LowerRETURNADDR(SDValue Op,
                                             SelectionDAG &DAG) const {
  MachineFunction &MF = DAG.getMachineFunction();
  MF.getFrameInfo().setReturnAddressIsTaken(true);
  SDLoc DL(Op);
  EVT VT = Op.getValueType();
  if (Op.getConstantOperandVal(0) != 0)
    report_fatal_error("NDS32 returnaddress only supports a depth of 0");
  // The return address is in $lp ($r30); mark it live-in so its incoming value
  // is available.
  Register Reg = MF.addLiveIn(NDS32::R30, &NDS32::GPRRegClass);
  return DAG.getCopyFromReg(DAG.getEntryNode(), DL, Reg, VT);
}

SDValue NDS32TargetLowering::LowerDYNAMIC_STACKALLOC(SDValue Op,
                                                     SelectionDAG &DAG) const {
  SDLoc DL(Op);
  EVT VT = Op.getValueType(); // i32
  SDValue Chain = Op.getOperand(0);
  SDValue Size = Op.getOperand(1);
  MaybeAlign Alloca = cast<ConstantSDNode>(Op.getOperand(2))->getMaybeAlignValue();

  // newSP = $sp - Size, then align down. The size operand is already rounded up
  // to the stack alignment by the legalizer; honor a larger alloca alignment.
  Register SPReg = NDS32::R31;
  SDValue SP = DAG.getCopyFromReg(Chain, DL, SPReg, VT);
  Chain = SP.getValue(1);
  SDValue NewSP = DAG.getNode(ISD::SUB, DL, VT, SP, Size);

  Align StackAlign = DAG.getSubtarget().getFrameLowering()->getStackAlign();
  Align A = std::max(Alloca.valueOrOne(), StackAlign);
  if (A > StackAlign)
    NewSP = DAG.getNode(ISD::AND, DL, VT, NewSP,
                        DAG.getSignedConstant(-(int64_t)A.value(), DL, VT));

  Chain = DAG.getCopyToReg(Chain, DL, SPReg, NewSP);
  // The allocated block starts at the new stack pointer.
  SDValue Ops[] = {NewSP, Chain};
  return DAG.getMergeValues(Ops, DL);
}

MachineBasicBlock *
NDS32TargetLowering::EmitInstrWithCustomInserter(MachineInstr &MI,
                                                 MachineBasicBlock *BB) const {
  assert(MI.getOpcode() == NDS32::Select &&
         "Unexpected instruction for custom inserter");

  const TargetInstrInfo &TII = *BB->getParent()->getSubtarget().getInstrInfo();
  const DebugLoc &DL = MI.getDebugLoc();
  MachineRegisterInfo &MRI = BB->getParent()->getRegInfo();

  Register DstReg = MI.getOperand(0).getReg();
  Register CondReg = MI.getOperand(1).getReg();
  Register TrueReg = MI.getOperand(2).getReg();
  Register FalseReg = MI.getOperand(3).getReg();

  // Branchless select via a cmovn/cmovz pair (no diamond, stays in one block):
  //
  //   tmp = IMPLICIT_DEF
  //   tmp = cmovn tmp, $true,  $cond   ; if cond != 0 -> tmp = true
  //   $dst = cmovz tmp, $false, $cond  ; if cond == 0 -> dst = false, else tmp
  //
  // Exactly one of the two conditional moves fires, so $dst is fully defined;
  // the IMPLICIT_DEF seed is never observed.
  Register Undef = MRI.createVirtualRegister(&NDS32::GPRRegClass);
  Register Tmp = MRI.createVirtualRegister(&NDS32::GPRRegClass);
  BuildMI(*BB, MI, DL, TII.get(TargetOpcode::IMPLICIT_DEF), Undef);
  BuildMI(*BB, MI, DL, TII.get(NDS32::CMOVN), Tmp)
      .addReg(Undef)
      .addReg(TrueReg)
      .addReg(CondReg);
  BuildMI(*BB, MI, DL, TII.get(NDS32::CMOVZ), DstReg)
      .addReg(Tmp)
      .addReg(FalseReg)
      .addReg(CondReg);

  MI.eraseFromParent();
  return BB;
}

//===----------------------------------------------------------------------===//
// Inline assembly support
//===----------------------------------------------------------------------===//

TargetLowering::ConstraintType
NDS32TargetLowering::getConstraintType(StringRef Constraint) const {
  if (Constraint.size() == 1) {
    switch (Constraint[0]) {
    case 'r':
      return C_RegisterClass;
    case 'I': // signed 15-bit immediate
    case 'J': // signed 20-bit immediate
    case 'K': // unsigned 15-bit immediate
      return C_Immediate;
    default:
      break;
    }
  }
  return TargetLowering::getConstraintType(Constraint);
}

std::pair<unsigned, const TargetRegisterClass *>
NDS32TargetLowering::getRegForInlineAsmConstraint(
    const TargetRegisterInfo *TRI, StringRef Constraint, MVT VT) const {
  if (Constraint.size() == 1 && Constraint[0] == 'r')
    return std::make_pair(0U, &NDS32::GPRRegClass);
  return TargetLowering::getRegForInlineAsmConstraint(TRI, Constraint, VT);
}

void NDS32TargetLowering::LowerAsmOperandForConstraint(
    SDValue Op, StringRef Constraint, std::vector<SDValue> &Ops,
    SelectionDAG &DAG) const {
  if (Constraint.size() == 1) {
    char C = Constraint[0];
    if (C == 'I' || C == 'J' || C == 'K') {
      auto *CN = dyn_cast<ConstantSDNode>(Op);
      if (!CN)
        return; // non-constant operand for an immediate constraint: reject
      int64_t Val = CN->getSExtValue();
      bool InRange = (C == 'I') ? isInt<15>(Val)
                   : (C == 'J') ? isInt<20>(Val)
                                : isUInt<15>(Val); // 'K'
      if (InRange)
        Ops.push_back(
            DAG.getSignedTargetConstant(Val, SDLoc(Op), Op.getValueType()));
      return; // out of range: add nothing (constraint not satisfied)
    }
  }
  TargetLowering::LowerAsmOperandForConstraint(Op, Constraint, Ops, DAG);
}
