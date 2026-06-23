class NDS32Inst<dag outs, dag ins, string asmstr, list<dag> pattern> : Instruction {
  let Namespace = "NDS32";
  let Size = 4;
  let OutOperandList = outs;
  let InOperandList = ins;
  let AsmString = asmstr;
  let Pattern = pattern;
}

def NDS32retflag : SDNode<"NDS32ISD::RET_FLAG", SDTNone,
                          [SDNPHasChain, SDNPOptInGlue, SDNPVariadic]>;

def NDS32wrapper : SDNode<"NDS32ISD::Wrapper", SDTIntUnaryOp>;

def SDT_NDS32Call : SDTypeProfile<0, 1, [SDTCisVT<0, i32>]>;
def NDS32call     : SDNode<"NDS32ISD::CALL", SDT_NDS32Call,
                           [SDNPHasChain, SDNPOptInGlue, SDNPOutGlue, SDNPVariadic]>;

def SDT_CallSeqStart : SDCallSeqStart<[SDTCisVT<0, i32>,
                                       SDTCisVT<1, i32>]>;
def SDT_CallSeqEnd   : SDCallSeqEnd<[SDTCisVT<0, i32>,
                                     SDTCisVT<1, i32>]>;

def callseq_start : SDNode<"ISD::CALLSEQ_START", SDT_CallSeqStart,
                           [SDNPHasChain, SDNPOutGlue]>;
def callseq_end   : SDNode<"ISD::CALLSEQ_END", SDT_CallSeqEnd,
                           [SDNPHasChain, SDNPOptInGlue, SDNPOutGlue]>;

def SDT_NDS32BrCC : SDTypeProfile<0, 4, [SDTCisVT<0, OtherVT>, SDTCisVT<1, i32>, SDTCisVT<2, i32>, SDTCisVT<3, OtherVT>]>;
def NDS32br_cc    : SDNode<"NDS32ISD::BR_CC", SDT_NDS32BrCC, [SDNPHasChain]>;

def SDT_NDS32SelectCC : SDTypeProfile<1, 3, [SDTCisVT<1, i32>, SDTCisSameAs<0, 2>, SDTCisSameAs<0, 3>]>;
def NDS32selectcc     : SDNode<"NDS32ISD::SELECT_CC", SDT_NDS32SelectCC>;

def brtarget : Operand<OtherVT>;

// Memory operand: base register + constant word-aligned byte offset.
def memri : Operand<i32> {
  let PrintMethod = "printMemOperand";
  let MIOperandInfo = (ops GPR, i32imm);
}

def memri8 : Operand<i32> {
  let PrintMethod = "printMemOperand";
  let MIOperandInfo = (ops GPR, i32imm);
}

def memri16 : Operand<i32> {
  let PrintMethod = "printMemOperand";
  let MIOperandInfo = (ops GPR, i32imm);
}

def addr : ComplexPattern<iPTR, 2, "selectMemAddr", [frameindex]>;

// Immediate-range predicates matching each instruction's encoded field width
// (verified against the Andes assembler): addi/slti/sltsi take a signed 15-bit
// immediate, the logical-immediate ops a zero-extended unsigned 15-bit one, and
// movi a signed 20-bit one. An immediate outside its instruction's range must
// be materialized into a register instead of being silently truncated, so each
// immediate-form pattern is gated on the matching predicate; out-of-range
// constants fall back to constant materialization + the register-form op.
def simm15 : PatLeaf<(imm), [{ return isInt<15>(N->getSExtValue()); }]>;
def uimm15 : PatLeaf<(imm), [{ return isUInt<15>(N->getZExtValue()); }]>;
def simm20 : PatLeaf<(imm), [{ return isInt<20>(N->getSExtValue()); }]>;

// Constants too wide for movi are built as sethi(hi20)+ori(lo12).
def imm_hi20 : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant((N->getZExtValue() >> 12) & 0xfffff,
                                   SDLoc(N), MVT::i32);
}]>;
def imm_lo12 : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant(N->getZExtValue() & 0xfff, SDLoc(N),
                                   MVT::i32);
}]>;
def imm_wide : PatLeaf<(imm), [{ return !isInt<20>(N->getSExtValue()); }]>;

// Minimal instructions for skeleton compilation
def NOP : NDS32Inst<(outs), (ins), "nop", []>;

def sethi_imm : Operand<i32>;
def SETHI : NDS32Inst<(outs GPR:$dst), (ins sethi_imm:$imm),
                      "sethi\t$dst, $imm", []>;

def MOVI : NDS32Inst<(outs GPR:$dst), (ins i32imm:$imm),
                     "movi\t$dst, $imm",
                     [(set GPR:$dst, simm20:$imm)]>;

def ADDrr : NDS32Inst<(outs GPR:$dst), (ins GPR:$lhs, GPR:$rhs),
                      "add\t$dst, $lhs, $rhs",
                      [(set GPR:$dst, (add GPR:$lhs, GPR:$rhs))]>;

def ADDri : NDS32Inst<(outs GPR:$dst), (ins GPR:$lhs, i32imm:$imm),
                      "addi\t$dst, $lhs, $imm",
                      [(set GPR:$dst, (add GPR:$lhs, simm15:$imm))]>;

def SUBrr : NDS32Inst<(outs GPR:$dst), (ins GPR:$lhs, GPR:$rhs),
                      "sub\t$dst, $lhs, $rhs",
                      [(set GPR:$dst, (sub GPR:$lhs, GPR:$rhs))]>;

def MULrr : NDS32Inst<(outs GPR:$dst), (ins GPR:$lhs, GPR:$rhs),
                      "mul\t$dst, $lhs, $rhs",
                      [(set GPR:$dst, (mul GPR:$lhs, GPR:$rhs))]>;

def DIVSR : NDS32Inst<(outs GPR:$quo, GPR:$rem), (ins GPR:$lhs, GPR:$rhs),
                      "divsr\t$quo, $rem, $lhs, $rhs",
                      [(set GPR:$quo, (sdiv GPR:$lhs, GPR:$rhs)),
                       (set GPR:$rem, (srem GPR:$lhs, GPR:$rhs))]>;

def DIVR : NDS32Inst<(outs GPR:$quo, GPR:$rem), (ins GPR:$lhs, GPR:$rhs),
                     "divr\t$quo, $rem, $lhs, $rhs",
                     [(set GPR:$quo, (udiv GPR:$lhs, GPR:$rhs)),
                      (set GPR:$rem, (urem GPR:$lhs, GPR:$rhs))]>;

def ANDrr : NDS32Inst<(outs GPR:$dst), (ins GPR:$lhs, GPR:$rhs),
                      "and\t$dst, $lhs, $rhs",
                      [(set GPR:$dst, (and GPR:$lhs, GPR:$rhs))]>;

def ORrr : NDS32Inst<(outs GPR:$dst), (ins GPR:$lhs, GPR:$rhs),
                     "or\t$dst, $lhs, $rhs",
                     [(set GPR:$dst, (or GPR:$lhs, GPR:$rhs))]>;

def XORrr : NDS32Inst<(outs GPR:$dst), (ins GPR:$lhs, GPR:$rhs),
                      "xor\t$dst, $lhs, $rhs",
                      [(set GPR:$dst, (xor GPR:$lhs, GPR:$rhs))]>;

def SLLrr : NDS32Inst<(outs GPR:$dst), (ins GPR:$lhs, GPR:$rhs),
                      "sll\t$dst, $lhs, $rhs",
                      [(set GPR:$dst, (shl GPR:$lhs, GPR:$rhs))]>;

def SRLrr : NDS32Inst<(outs GPR:$dst), (ins GPR:$lhs, GPR:$rhs),
                      "srl\t$dst, $lhs, $rhs",
                      [(set GPR:$dst, (srl GPR:$lhs, GPR:$rhs))]>;

def SRArr : NDS32Inst<(outs GPR:$dst), (ins GPR:$lhs, GPR:$rhs),
                      "sra\t$dst, $lhs, $rhs",
                      [(set GPR:$dst, (sra GPR:$lhs, GPR:$rhs))]>;

// Sign/zero-extend byte/halfword (register form).
def SEB : NDS32Inst<(outs GPR:$dst), (ins GPR:$src),
                    "seb\t$dst, $src",
                    [(set GPR:$dst, (sext_inreg GPR:$src, i8))]>;
def SEH : NDS32Inst<(outs GPR:$dst), (ins GPR:$src),
                    "seh\t$dst, $src",
                    [(set GPR:$dst, (sext_inreg GPR:$src, i16))]>;
def ZEH : NDS32Inst<(outs GPR:$dst), (ins GPR:$src),
                    "zeh\t$dst, $src",
                    [(set GPR:$dst, (and GPR:$src, 0xffff))]>;

// Count leading zeros. clz returns 32 for a zero input, matching both
// ISD::CTLZ and ISD::CTLZ_ZERO_UNDEF.
def CLZ : NDS32Inst<(outs GPR:$dst), (ins GPR:$src),
                    "clz\t$dst, $src",
                    [(set GPR:$dst, (ctlz GPR:$src))]>;
def : Pat<(ctlz_zero_undef GPR:$src), (CLZ GPR:$src)>;

// Byte-swap within each halfword (0xAABBCCDD -> 0xBBAADDCC) and rotate-right by
// immediate. Composed, they form a full 32-bit byte reverse (BSWAP):
// rotri(wsbh(x), 16) = 0xDDCCBBAA.
def WSBH : NDS32Inst<(outs GPR:$dst), (ins GPR:$src),
                     "wsbh\t$dst, $src", []>;
def ROTRIri : NDS32Inst<(outs GPR:$dst), (ins GPR:$src, i32imm:$sa),
                        "rotri\t$dst, $src, $sa", []>;
def : Pat<(bswap GPR:$src), (ROTRIri (WSBH GPR:$src), (i32 16))>;

// Conditional moves: each conditionally overwrites $dst and preserves it
// otherwise, so $dstin is tied to $dst. cmovz writes when $cond == 0, cmovn
// when $cond != 0. The branchless select expansion emits a cmovn/cmovz pair
// (see EmitInstrWithCustomInserter); exactly one fires, fully defining $dst.
let Constraints = "$dstin = $dst" in {
def CMOVZ : NDS32Inst<(outs GPR:$dst), (ins GPR:$dstin, GPR:$src, GPR:$cond),
                      "cmovz\t$dst, $src, $cond", []>;
def CMOVN : NDS32Inst<(outs GPR:$dst), (ins GPR:$dstin, GPR:$src, GPR:$cond),
                      "cmovn\t$dst, $src, $cond", []>;

// Fused multiply-accumulate / multiply-subtract (low 32 bits): the running
// accumulator $dstin is tied to $dst.
def MADDR32 : NDS32Inst<(outs GPR:$dst), (ins GPR:$dstin, GPR:$a, GPR:$b),
                        "maddr32\t$dst, $a, $b",
                        [(set GPR:$dst, (add GPR:$dstin, (mul GPR:$a, GPR:$b)))]>;
def MSUBR32 : NDS32Inst<(outs GPR:$dst), (ins GPR:$dstin, GPR:$a, GPR:$b),
                        "msubr32\t$dst, $a, $b",
                        [(set GPR:$dst, (sub GPR:$dstin, (mul GPR:$a, GPR:$b)))]>;
}

def ANDri : NDS32Inst<(outs GPR:$dst), (ins GPR:$lhs, i32imm:$imm),
                      "andi\t$dst, $lhs, $imm",
                      [(set GPR:$dst, (and GPR:$lhs, uimm15:$imm))]>;

// bitci rt, ra, #imm15: rt = ra & ~zext(imm15). Matches an AND with a constant
// whose complement fits in 15 unsigned bits (i.e. only low bits are cleared),
// saving a movi+and. The operand carries the cleared mask (~C).
def bitci_xform : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant(~(uint32_t)N->getZExtValue() & 0x7fff,
                                   SDLoc(N), MVT::i32);
}]>;
def imm_bitci : PatLeaf<(imm), [{
  return isUInt<15>(~(uint32_t)N->getZExtValue());
}], bitci_xform>;
def BITCI : NDS32Inst<(outs GPR:$dst), (ins GPR:$ra, i32imm:$imm),
                      "bitci\t$dst, $ra, $imm",
                      [(set GPR:$dst, (and GPR:$ra, imm_bitci:$imm))]>;

def ORri : NDS32Inst<(outs GPR:$dst), (ins GPR:$lhs, i32imm:$imm),
                     "ori\t$dst, $lhs, $imm",
                     [(set GPR:$dst, (or GPR:$lhs, uimm15:$imm))]>;

def XORri : NDS32Inst<(outs GPR:$dst), (ins GPR:$lhs, i32imm:$imm),
                      "xori\t$dst, $lhs, $imm",
                      [(set GPR:$dst, (xor GPR:$lhs, uimm15:$imm))]>;

def SLLIri : NDS32Inst<(outs GPR:$dst), (ins GPR:$lhs, i32imm:$imm),
                       "slli\t$dst, $lhs, $imm",
                       [(set GPR:$dst, (shl GPR:$lhs, imm:$imm))]>;

def SRLIri : NDS32Inst<(outs GPR:$dst), (ins GPR:$lhs, i32imm:$imm),
                       "srli\t$dst, $lhs, $imm",
                       [(set GPR:$dst, (srl GPR:$lhs, imm:$imm))]>;

def SRAIri : NDS32Inst<(outs GPR:$dst), (ins GPR:$lhs, i32imm:$imm),
                       "srai\t$dst, $lhs, $imm",
                       [(set GPR:$dst, (sra GPR:$lhs, imm:$imm))]>;

def SLT : NDS32Inst<(outs GPR:$dst), (ins GPR:$lhs, GPR:$rhs),
                    "slt\t$dst, $lhs, $rhs",
                    [(set GPR:$dst, (setcc GPR:$lhs, GPR:$rhs, SETULT))]>;

def SLTS : NDS32Inst<(outs GPR:$dst), (ins GPR:$lhs, GPR:$rhs),
                     "slts\t$dst, $lhs, $rhs",
                     [(set GPR:$dst, (setcc GPR:$lhs, GPR:$rhs, SETLT))]>;

def SLTI : NDS32Inst<(outs GPR:$dst), (ins GPR:$lhs, i32imm:$imm),
                     "slti\t$dst, $lhs, $imm",
                     [(set GPR:$dst, (setcc GPR:$lhs, simm15:$imm, SETULT))]>;

def SLTSI : NDS32Inst<(outs GPR:$dst), (ins GPR:$lhs, i32imm:$imm),
                      "sltsi\t$dst, $lhs, $imm",
                      [(set GPR:$dst, (setcc GPR:$lhs, simm15:$imm, SETLT))]>;

def LWI : NDS32Inst<(outs GPR:$dst), (ins memri:$addr),
                    "lwi\t$dst, [$addr]",
                    [(set GPR:$dst, (load addr:$addr))]>;

def LBI : NDS32Inst<(outs GPR:$dst), (ins memri8:$addr),
                    "lbi\t$dst, [$addr]",
                    [(set GPR:$dst, (zextloadi8 addr:$addr))]>;

def LBSI : NDS32Inst<(outs GPR:$dst), (ins memri8:$addr),
                     "lbsi\t$dst, [$addr]",
                     [(set GPR:$dst, (sextloadi8 addr:$addr))]>;

def LHI : NDS32Inst<(outs GPR:$dst), (ins memri16:$addr),
                    "lhi\t$dst, [$addr]",
                    [(set GPR:$dst, (zextloadi16 addr:$addr))]>;

def LHSI : NDS32Inst<(outs GPR:$dst), (ins memri16:$addr),
                     "lhsi\t$dst, [$addr]",
                     [(set GPR:$dst, (sextloadi16 addr:$addr))]>;

def SWI : NDS32Inst<(outs), (ins GPR:$src, memri:$addr),
                    "swi\t$src, [$addr]",
                    [(store GPR:$src, addr:$addr)]>;

def SBI : NDS32Inst<(outs), (ins GPR:$src, memri8:$addr),
                    "sbi\t$src, [$addr]",
                    [(truncstorei8 GPR:$src, addr:$addr)]>;

def SHI : NDS32Inst<(outs), (ins GPR:$src, memri16:$addr),
                    "shi\t$src, [$addr]",
                    [(truncstorei16 GPR:$src, addr:$addr)]>;

// Any-extending narrow loads (don't care about the high bits): reuse the
// zero-extending byte/halfword loads.
def : Pat<(i32 (extloadi8 addr:$addr)),  (LBI memri8:$addr)>;
def : Pat<(i32 (extloadi16 addr:$addr)), (LHI memri16:$addr)>;
// A 1-bit (i1) load is materialized as a byte load.
def : Pat<(i32 (extloadi1 addr:$addr)),  (LBI memri8:$addr)>;

let isReturn = 1, isTerminator = 1, isBarrier = 1 in
def RET : NDS32Inst<(outs), (ins), "ret", [(NDS32retflag)]>;

let isBranch = 1, isTerminator = 1, isBarrier = 1 in
def BR : NDS32Inst<(outs), (ins brtarget:$dst), "b\t$dst", [(br bb:$dst)]>;

// Indirect jump (jr $rs): used for jump-table dispatch (brind).
let isBranch = 1, isTerminator = 1, isBarrier = 1, isIndirectBranch = 1 in
def JR : NDS32Inst<(outs), (ins GPR:$rs), "jr\t$rs", [(brind GPR:$rs)]>;

def call_target : Operand<i32>;

let isCall = 1, Defs = [R30] in {
  def JAL : NDS32Inst<(outs), (ins call_target:$dst), "jal\t$dst", []>;
  def JRAL : NDS32Inst<(outs), (ins GPR:$dst), "jral\t$dst", []>;
}

class Pseudo<dag outs, dag ins, string asmstr, list<dag> pattern>
    : Instruction {
  let Namespace = "NDS32";
  let Size = 0;
  let OutOperandList = outs;
  let InOperandList = ins;
  let AsmString = asmstr;
  let Pattern = pattern;
  let isCodeGenOnly = 1;
  let isPseudo = 1;
}

let Defs = [R31], Uses = [R31] in {
def ADJCALLSTACKDOWN : Pseudo<(outs), (ins i32imm:$amt1, i32imm:$amt2),
                              "# ADJCALLSTACKDOWN $amt1",
                              [(callseq_start timm:$amt1, timm:$amt2)]>;
def ADJCALLSTACKUP   : Pseudo<(outs), (ins i32imm:$amt1, i32imm:$amt2),
                              "# ADJCALLSTACKUP $amt1",
                              [(callseq_end timm:$amt1, timm:$amt2)]>;
}

// Select pseudo: expanded by EmitInstrWithCustomInserter into a control-flow
// diamond that branches on $cond (BNEZ) and selects $t or $f via a PHI.
let usesCustomInserter = 1 in
def Select : Pseudo<(outs GPR:$dst), (ins GPR:$cond, GPR:$t, GPR:$f),
                    "# Select $dst = $cond ? $t : $f",
                    [(set GPR:$dst, (NDS32selectcc GPR:$cond, GPR:$t, GPR:$f))]>;

let isBranch = 1, isTerminator = 1 in {
def BEQZ : NDS32Inst<(outs), (ins GPR:$lhs, brtarget:$dst),
                     "beqz\t$lhs, $dst",
                     [(NDS32br_cc SETEQ, GPR:$lhs, (i32 0), bb:$dst)]>;

def BNEZ : NDS32Inst<(outs), (ins GPR:$lhs, brtarget:$dst),
                     "bnez\t$lhs, $dst",
                     [(NDS32br_cc SETNE, GPR:$lhs, (i32 0), bb:$dst)]>;

def BGEZ : NDS32Inst<(outs), (ins GPR:$lhs, brtarget:$dst),
                     "bgez\t$lhs, $dst",
                     [(NDS32br_cc SETGE, GPR:$lhs, (i32 0), bb:$dst)]>;

def BLTZ : NDS32Inst<(outs), (ins GPR:$lhs, brtarget:$dst),
                     "bltz\t$lhs, $dst",
                     [(NDS32br_cc SETLT, GPR:$lhs, (i32 0), bb:$dst)]>;

def BGTZ : NDS32Inst<(outs), (ins GPR:$lhs, brtarget:$dst),
                     "bgtz\t$lhs, $dst",
                     [(NDS32br_cc SETGT, GPR:$lhs, (i32 0), bb:$dst)]>;

def BLEZ : NDS32Inst<(outs), (ins GPR:$lhs, brtarget:$dst),
                     "blez\t$lhs, $dst",
                     [(NDS32br_cc SETLE, GPR:$lhs, (i32 0), bb:$dst)]>;

def BEQ : NDS32Inst<(outs), (ins GPR:$lhs, GPR:$rhs, brtarget:$dst),
                    "beq\t$lhs, $rhs, $dst",
                    [(NDS32br_cc SETEQ, GPR:$lhs, GPR:$rhs, bb:$dst)]>;

def BNE : NDS32Inst<(outs), (ins GPR:$lhs, GPR:$rhs, brtarget:$dst),
                    "bne\t$lhs, $rhs, $dst",
                    [(NDS32br_cc SETNE, GPR:$lhs, GPR:$rhs, bb:$dst)]>;
}

// SETHI patterns: NDS32wrapper(tglobaladdr/texternalsym/tconstpool) → SETHI.
def : Pat<(NDS32wrapper tglobaladdr:$imm), (SETHI tglobaladdr:$imm)>;
def : Pat<(NDS32wrapper texternalsym:$imm), (SETHI texternalsym:$imm)>;
def : Pat<(NDS32wrapper tconstpool:$imm), (SETHI tconstpool:$imm)>;
def : Pat<(NDS32wrapper tjumptable:$imm), (SETHI tjumptable:$imm)>;

// ADDri patterns for global-address lower-half (address computation).
def : Pat<(add GPR:$lhs, (NDS32wrapper tglobaladdr:$imm)),
          (ADDri GPR:$lhs, tglobaladdr:$imm)>;
def : Pat<(add GPR:$lhs, (NDS32wrapper texternalsym:$imm)),
          (ADDri GPR:$lhs, texternalsym:$imm)>;
def : Pat<(add GPR:$lhs, (NDS32wrapper tconstpool:$imm)),
          (ADDri GPR:$lhs, tconstpool:$imm)>;
def : Pat<(add GPR:$lhs, (NDS32wrapper tjumptable:$imm)),
          (ADDri GPR:$lhs, tjumptable:$imm)>;

// JAL patterns.
def : Pat<(NDS32call tglobaladdr:$dst), (JAL tglobaladdr:$dst)>;
def : Pat<(NDS32call texternalsym:$dst), (JAL texternalsym:$dst)>;
def : Pat<(NDS32call GPR:$dst), (JRAL GPR:$dst)>;

// Division instructions produce quotient and remainder together.
def : Pat<(sdivrem GPR:$lhs, GPR:$rhs), (DIVSR GPR:$lhs, GPR:$rhs)>;
def : Pat<(udivrem GPR:$lhs, GPR:$rhs), (DIVR GPR:$lhs, GPR:$rhs)>;

// A constant wider than movi's signed 20-bit field: sethi the high 20 bits then
// ori the low 12. (SETHI loads imm20 << 12; ori fills bits [11:0].)
def : Pat<(i32 imm_wide:$imm),
          (ORri (SETHI (imm_hi20 imm:$imm)), (imm_lo12 imm:$imm))>;
