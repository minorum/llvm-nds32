class NDS32Inst<dag outs, dag ins, string asmstr, list<dag> pattern> : Instruction {
  let Namespace = "NDS32";
  let Size = 4;
  let OutOperandList = outs;
  let InOperandList = ins;
  let AsmString = asmstr;
  let Pattern = pattern;
  // Encoding migration (Round 3 tooling): instructions whose Inst{} fields are
  // filled in are validated by NDS32MCCodeEmitter against the hand-written
  // encoder; the rest still encode via the hand-written switch.
  field bits<32> Inst;
}

// ALU register format: op6 in Inst[31:25], rt/ra/rb in the standard fields, a
// sub-opcode in Inst[9:0].
class ALUrrr<bits<7> op6, bits<10> sub, dag outs, dag ins, string asmstr,
             list<dag> pattern>
    : NDS32Inst<outs, ins, asmstr, pattern> {
  bits<5> rt;
  bits<5> ra;
  bits<5> rb;
  let Inst{31-25} = op6;
  let Inst{24-20} = rt;
  let Inst{19-15} = ra;
  let Inst{14-10} = rb;
  let Inst{9-0} = sub;
}

// Two-register ALU format (rb field unused / zero).
class ALU2r<bits<7> op6, bits<10> sub, dag outs, dag ins, string asmstr,
            list<dag> pattern>
    : NDS32Inst<outs, ins, asmstr, pattern> {
  bits<5> rt;
  bits<5> ra;
  let Inst{31-25} = op6;
  let Inst{24-20} = rt;
  let Inst{19-15} = ra;
  let Inst{14-10} = 0;
  let Inst{9-0} = sub;
}

// Shift-by-immediate format: 5-bit shift amount in the rb field [14:10].
class ALUsa<bits<7> op6, bits<10> sub, dag outs, dag ins, string asmstr,
            list<dag> pattern>
    : NDS32Inst<outs, ins, asmstr, pattern> {
  bits<5> rt;
  bits<5> ra;
  bits<5> sa;
  let Inst{31-25} = op6;
  let Inst{24-20} = rt;
  let Inst{19-15} = ra;
  let Inst{14-10} = sa;
  let Inst{9-0} = sub;
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
def brtarget25 : Operand<OtherVT> { let EncoderMethod = "encodeBr25"; }
def brtarget17 : Operand<OtherVT> { let EncoderMethod = "encodeBr17"; }
def brtarget15 : Operand<OtherVT> { let EncoderMethod = "encodeBr15"; }

// j/jal: 8-bit opcode in Inst[31:24], 24-bit (halfword) target in [23:0].
class JF<bits<8> op8, dag outs, dag ins, string asmstr, list<dag> pattern>
    : NDS32Inst<outs, ins, asmstr, pattern> {
  bits<24> target;
  let Inst{31-24} = op8;
  let Inst{23-0} = target;
}

// beqz/bnez/bgez/bltz/bgtz/blez: op6=0x27, rt, 3-bit condition in [18:16],
// 16-bit (halfword) target in [15:0].
class Br17<bits<3> cond, dag outs, dag ins, string asmstr, list<dag> pattern>
    : NDS32Inst<outs, ins, asmstr, pattern> {
  bits<5> rt;
  bits<16> target;
  let Inst{31-25} = 0x27;
  let Inst{24-20} = rt;
  let Inst{19} = 0;
  let Inst{18-16} = cond;
  let Inst{15-0} = target;
}

// beq/bne: op6=0x26, rt, ra, bit14 selects ne, 14-bit (halfword) target.
class Br15<bits<1> ne, dag outs, dag ins, string asmstr, list<dag> pattern>
    : NDS32Inst<outs, ins, asmstr, pattern> {
  bits<5> rt;
  bits<5> ra;
  bits<14> target;
  let Inst{31-25} = 0x26;
  let Inst{24-20} = rt;
  let Inst{19-15} = ra;
  let Inst{14} = ne;
  let Inst{13-0} = target;
}

// I-type 15-bit immediate (carries lo12 symbol fixups via encodeImm15).
def imm15op : Operand<i32> { let EncoderMethod = "encodeImm15"; }
// 20-bit immediate (movi / sethi hi20 fixups).
def imm20op : Operand<i32> { let EncoderMethod = "encodeImm20"; }

// Memory operand: base register + constant word-aligned byte offset. The
// EncoderMethod packs base[19:15] and the scaled offset[14:0] into Inst[19:0].
def memri : Operand<i32> {
  let PrintMethod = "printMemOperand";
  let MIOperandInfo = (ops GPR, i32imm);
  let EncoderMethod = "encodeMemWords";
}

def memri8 : Operand<i32> {
  let PrintMethod = "printMemOperand";
  let MIOperandInfo = (ops GPR, i32imm);
  let EncoderMethod = "encodeMemBytes";
}

def memri16 : Operand<i32> {
  let PrintMethod = "printMemOperand";
  let MIOperandInfo = (ops GPR, i32imm);
  let EncoderMethod = "encodeMemHalfwords";
}

// I-type immediate ALU format.
class ALUi15<bits<7> op6, dag outs, dag ins, string asmstr, list<dag> pattern>
    : NDS32Inst<outs, ins, asmstr, pattern> {
  bits<5> rt;
  bits<5> ra;
  bits<15> imm;
  let Inst{31-25} = op6;
  let Inst{24-20} = rt;
  let Inst{19-15} = ra;
  let Inst{14-0} = imm;
}

// Load/store format: rt in [24:20] (the value for stores), memory operand
// packed into [19:0].
class MemF<bits<7> op6, dag outs, dag ins, string asmstr, list<dag> pattern>
    : NDS32Inst<outs, ins, asmstr, pattern> {
  bits<5> rt;
  bits<20> addr;
  let Inst{31-25} = op6;
  let Inst{24-20} = rt;
  let Inst{19-0} = addr;
}

// movi / sethi: a 20-bit immediate in Inst[19:0].
class MoviF<bits<7> op6, dag outs, dag ins, string asmstr, list<dag> pattern>
    : NDS32Inst<outs, ins, asmstr, pattern> {
  bits<5> rt;
  bits<20> imm;
  let Inst{31-25} = op6;
  let Inst{24-20} = rt;
  let Inst{19-0} = imm;
}

def addr : ComplexPattern<iPTR, 2, "selectMemAddr", [frameindex]>;

// Register-offset addressing: base register + (index << scale), scale in 0..3.
def memrr : Operand<i32> {
  let PrintMethod = "printRegOffsetMem";
  let MIOperandInfo = (ops GPR, GPR, i32imm);
}
def regoaddr : ComplexPattern<iPTR, 3, "selectRegOffsetAddr", []>;

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
def NOP : NDS32Inst<(outs), (ins), "nop", []> { let Inst = 0x40000009; }

def sethi_imm : Operand<i32> { let EncoderMethod = "encodeImm20"; }
def SETHI : MoviF<0x23, (outs GPR:$rt), (ins sethi_imm:$imm),
                  "sethi\t$rt, $imm", []>;

def MOVI : MoviF<0x22, (outs GPR:$rt), (ins imm20op:$imm),
                 "movi\t$rt, $imm",
                 [(set GPR:$rt, simm20:$imm)]>;

def ADDrr : ALUrrr<0x20, 0, (outs GPR:$rt), (ins GPR:$ra, GPR:$rb),
                   "add\t$rt, $ra, $rb",
                   [(set GPR:$rt, (add GPR:$ra, GPR:$rb))]>;

def ADDri : ALUi15<0x28, (outs GPR:$rt), (ins GPR:$ra, imm15op:$imm),
                   "addi\t$rt, $ra, $imm",
                   [(set GPR:$rt, (add GPR:$ra, simm15:$imm))]>;

def SUBrr : ALUrrr<0x20, 1, (outs GPR:$rt), (ins GPR:$ra, GPR:$rb),
                   "sub\t$rt, $ra, $rb",
                   [(set GPR:$rt, (sub GPR:$ra, GPR:$rb))]>;

def MULrr : ALUrrr<0x21, 0x24, (outs GPR:$rt), (ins GPR:$ra, GPR:$rb),
                   "mul\t$rt, $ra, $rb",
                   [(set GPR:$rt, (mul GPR:$ra, GPR:$rb))]>;

def DIVSR : NDS32Inst<(outs GPR:$quo, GPR:$rem), (ins GPR:$lhs, GPR:$rhs),
                      "divsr\t$quo, $rem, $lhs, $rhs",
                      [(set GPR:$quo, (sdiv GPR:$lhs, GPR:$rhs)),
                       (set GPR:$rem, (srem GPR:$lhs, GPR:$rhs))]>;

def DIVR : NDS32Inst<(outs GPR:$quo, GPR:$rem), (ins GPR:$lhs, GPR:$rhs),
                     "divr\t$quo, $rem, $lhs, $rhs",
                     [(set GPR:$quo, (udiv GPR:$lhs, GPR:$rhs)),
                      (set GPR:$rem, (urem GPR:$lhs, GPR:$rhs))]>;

def ANDrr : ALUrrr<0x20, 2, (outs GPR:$rt), (ins GPR:$ra, GPR:$rb),
                   "and\t$rt, $ra, $rb",
                   [(set GPR:$rt, (and GPR:$ra, GPR:$rb))]>;

def ORrr : ALUrrr<0x20, 4, (outs GPR:$rt), (ins GPR:$ra, GPR:$rb),
                  "or\t$rt, $ra, $rb",
                  [(set GPR:$rt, (or GPR:$ra, GPR:$rb))]>;

def XORrr : ALUrrr<0x20, 3, (outs GPR:$rt), (ins GPR:$ra, GPR:$rb),
                   "xor\t$rt, $ra, $rb",
                   [(set GPR:$rt, (xor GPR:$ra, GPR:$rb))]>;

def SLLrr : ALUrrr<0x20, 0xc, (outs GPR:$rt), (ins GPR:$ra, GPR:$rb),
                   "sll\t$rt, $ra, $rb",
                   [(set GPR:$rt, (shl GPR:$ra, GPR:$rb))]>;

def SRLrr : ALUrrr<0x20, 0xd, (outs GPR:$rt), (ins GPR:$ra, GPR:$rb),
                   "srl\t$rt, $ra, $rb",
                   [(set GPR:$rt, (srl GPR:$ra, GPR:$rb))]>;

def SRArr : ALUrrr<0x20, 0xe, (outs GPR:$rt), (ins GPR:$ra, GPR:$rb),
                   "sra\t$rt, $ra, $rb",
                   [(set GPR:$rt, (sra GPR:$ra, GPR:$rb))]>;

// Sign/zero-extend byte/halfword (register form).
def SEB : ALU2r<0x20, 0x10, (outs GPR:$rt), (ins GPR:$ra),
                "seb\t$rt, $ra",
                [(set GPR:$rt, (sext_inreg GPR:$ra, i8))]>;
def SEH : ALU2r<0x20, 0x11, (outs GPR:$rt), (ins GPR:$ra),
                "seh\t$rt, $ra",
                [(set GPR:$rt, (sext_inreg GPR:$ra, i16))]>;
def ZEH : ALU2r<0x20, 0x13, (outs GPR:$rt), (ins GPR:$ra),
                "zeh\t$rt, $ra",
                [(set GPR:$rt, (and GPR:$ra, 0xffff))]>;

// Count leading zeros. clz returns 32 for a zero input, matching both
// ISD::CTLZ and ISD::CTLZ_ZERO_UNDEF.
def CLZ : ALU2r<0x21, 7, (outs GPR:$rt), (ins GPR:$ra),
                "clz\t$rt, $ra",
                [(set GPR:$rt, (ctlz GPR:$ra))]>;
def : Pat<(ctlz_zero_undef GPR:$src), (CLZ GPR:$src)>;

// Byte-swap within each halfword (0xAABBCCDD -> 0xBBAADDCC) and rotate-right by
// immediate. Composed, they form a full 32-bit byte reverse (BSWAP):
// rotri(wsbh(x), 16) = 0xDDCCBBAA.
def WSBH : ALU2r<0x20, 0x14, (outs GPR:$rt), (ins GPR:$ra),
                 "wsbh\t$rt, $ra", []>;
def ROTRIri : ALUsa<0x20, 0xb, (outs GPR:$rt), (ins GPR:$ra, i32imm:$sa),
                    "rotri\t$rt, $ra, $sa", []>;
def : Pat<(bswap GPR:$src), (ROTRIri (WSBH GPR:$src), (i32 16))>;

// Conditional moves: each conditionally overwrites $dst and preserves it
// otherwise, so $dstin is tied to $dst. cmovz writes when $cond == 0, cmovn
// when $cond != 0. The branchless select expansion emits a cmovn/cmovz pair
// (see EmitInstrWithCustomInserter); exactly one fires, fully defining $dst.
let Constraints = "$dstin = $rt" in {
def CMOVZ : ALUrrr<0x20, 0x1a, (outs GPR:$rt), (ins GPR:$dstin, GPR:$ra, GPR:$rb),
                   "cmovz\t$rt, $ra, $rb", []>;
def CMOVN : ALUrrr<0x20, 0x1b, (outs GPR:$rt), (ins GPR:$dstin, GPR:$ra, GPR:$rb),
                   "cmovn\t$rt, $ra, $rb", []>;

// Fused multiply-accumulate / multiply-subtract (low 32 bits): the running
// accumulator $dstin is tied to $rt.
def MADDR32 : ALUrrr<0x21, 0x73, (outs GPR:$rt),
                     (ins GPR:$dstin, GPR:$ra, GPR:$rb),
                     "maddr32\t$rt, $ra, $rb",
                     [(set GPR:$rt, (add GPR:$dstin, (mul GPR:$ra, GPR:$rb)))]>;
def MSUBR32 : ALUrrr<0x21, 0x75, (outs GPR:$rt),
                     (ins GPR:$dstin, GPR:$ra, GPR:$rb),
                     "msubr32\t$rt, $ra, $rb",
                     [(set GPR:$rt, (sub GPR:$dstin, (mul GPR:$ra, GPR:$rb)))]>;
}

def ANDri : ALUi15<0x2a, (outs GPR:$rt), (ins GPR:$ra, imm15op:$imm),
                   "andi\t$rt, $ra, $imm",
                   [(set GPR:$rt, (and GPR:$ra, uimm15:$imm))]>;

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
def BITCI : ALUi15<0x33, (outs GPR:$rt), (ins GPR:$ra, imm15op:$imm),
                   "bitci\t$rt, $ra, $imm",
                   [(set GPR:$rt, (and GPR:$ra, imm_bitci:$imm))]>;

def ORri : ALUi15<0x2c, (outs GPR:$rt), (ins GPR:$ra, imm15op:$imm),
                  "ori\t$rt, $ra, $imm",
                  [(set GPR:$rt, (or GPR:$ra, uimm15:$imm))]>;

def XORri : ALUi15<0x2b, (outs GPR:$rt), (ins GPR:$ra, imm15op:$imm),
                   "xori\t$rt, $ra, $imm",
                   [(set GPR:$rt, (xor GPR:$ra, uimm15:$imm))]>;

def SLLIri : ALUsa<0x20, 8, (outs GPR:$rt), (ins GPR:$ra, i32imm:$sa),
                   "slli\t$rt, $ra, $sa",
                   [(set GPR:$rt, (shl GPR:$ra, imm:$sa))]>;

def SRLIri : ALUsa<0x20, 9, (outs GPR:$rt), (ins GPR:$ra, i32imm:$sa),
                   "srli\t$rt, $ra, $sa",
                   [(set GPR:$rt, (srl GPR:$ra, imm:$sa))]>;

def SRAIri : ALUsa<0x20, 0xa, (outs GPR:$rt), (ins GPR:$ra, i32imm:$sa),
                   "srai\t$rt, $ra, $sa",
                   [(set GPR:$rt, (sra GPR:$ra, imm:$sa))]>;

def SLT : ALUrrr<0x20, 6, (outs GPR:$rt), (ins GPR:$ra, GPR:$rb),
                 "slt\t$rt, $ra, $rb",
                 [(set GPR:$rt, (setcc GPR:$ra, GPR:$rb, SETULT))]>;

def SLTS : ALUrrr<0x20, 7, (outs GPR:$rt), (ins GPR:$ra, GPR:$rb),
                  "slts\t$rt, $ra, $rb",
                  [(set GPR:$rt, (setcc GPR:$ra, GPR:$rb, SETLT))]>;

def SLTI : ALUi15<0x2e, (outs GPR:$rt), (ins GPR:$ra, imm15op:$imm),
                  "slti\t$rt, $ra, $imm",
                  [(set GPR:$rt, (setcc GPR:$ra, simm15:$imm, SETULT))]>;

def SLTSI : ALUi15<0x2f, (outs GPR:$rt), (ins GPR:$ra, imm15op:$imm),
                   "sltsi\t$rt, $ra, $imm",
                   [(set GPR:$rt, (setcc GPR:$ra, simm15:$imm, SETLT))]>;

def LWI : MemF<0x02, (outs GPR:$rt), (ins memri:$addr),
               "lwi\t$rt, [$addr]",
               [(set GPR:$rt, (load addr:$addr))]>;

def LBI : MemF<0x00, (outs GPR:$rt), (ins memri8:$addr),
               "lbi\t$rt, [$addr]",
               [(set GPR:$rt, (zextloadi8 addr:$addr))]>;

def LBSI : MemF<0x10, (outs GPR:$rt), (ins memri8:$addr),
                "lbsi\t$rt, [$addr]",
                [(set GPR:$rt, (sextloadi8 addr:$addr))]>;

def LHI : MemF<0x01, (outs GPR:$rt), (ins memri16:$addr),
               "lhi\t$rt, [$addr]",
               [(set GPR:$rt, (zextloadi16 addr:$addr))]>;

def LHSI : MemF<0x11, (outs GPR:$rt), (ins memri16:$addr),
                "lhsi\t$rt, [$addr]",
                [(set GPR:$rt, (sextloadi16 addr:$addr))]>;

def SWI : MemF<0x0a, (outs), (ins GPR:$rt, memri:$addr),
               "swi\t$rt, [$addr]",
               [(store GPR:$rt, addr:$addr)]>;

def SBI : MemF<0x08, (outs), (ins GPR:$rt, memri8:$addr),
               "sbi\t$rt, [$addr]",
               [(truncstorei8 GPR:$rt, addr:$addr)]>;

def SHI : MemF<0x09, (outs), (ins GPR:$rt, memri16:$addr),
               "shi\t$rt, [$addr]",
               [(truncstorei16 GPR:$rt, addr:$addr)]>;

// Register-offset loads and stores: address = base + (index << scale).
def LW_RR : NDS32Inst<(outs GPR:$rt), (ins memrr:$addr),
                      "lw\t$rt, [$addr]",
                      [(set GPR:$rt, (load regoaddr:$addr))]>;
def LB_RR : NDS32Inst<(outs GPR:$rt), (ins memrr:$addr),
                      "lb\t$rt, [$addr]",
                      [(set GPR:$rt, (zextloadi8 regoaddr:$addr))]>;
def LBS_RR : NDS32Inst<(outs GPR:$rt), (ins memrr:$addr),
                       "lbs\t$rt, [$addr]",
                       [(set GPR:$rt, (sextloadi8 regoaddr:$addr))]>;
def LH_RR : NDS32Inst<(outs GPR:$rt), (ins memrr:$addr),
                      "lh\t$rt, [$addr]",
                      [(set GPR:$rt, (zextloadi16 regoaddr:$addr))]>;
def LHS_RR : NDS32Inst<(outs GPR:$rt), (ins memrr:$addr),
                       "lhs\t$rt, [$addr]",
                       [(set GPR:$rt, (sextloadi16 regoaddr:$addr))]>;
def SW_RR : NDS32Inst<(outs), (ins GPR:$rt, memrr:$addr),
                      "sw\t$rt, [$addr]",
                      [(store GPR:$rt, regoaddr:$addr)]>;
def SB_RR : NDS32Inst<(outs), (ins GPR:$rt, memrr:$addr),
                      "sb\t$rt, [$addr]",
                      [(truncstorei8 GPR:$rt, regoaddr:$addr)]>;
def SH_RR : NDS32Inst<(outs), (ins GPR:$rt, memrr:$addr),
                      "sh\t$rt, [$addr]",
                      [(truncstorei16 GPR:$rt, regoaddr:$addr)]>;
def : Pat<(i32 (extloadi8 regoaddr:$addr)),  (LB_RR memrr:$addr)>;
def : Pat<(i32 (extloadi16 regoaddr:$addr)), (LH_RR memrr:$addr)>;
def : Pat<(i32 (extloadi1 regoaddr:$addr)),  (LB_RR memrr:$addr)>;

// Post-increment loads/stores: access [$ra], then $ra += $imm (byte units; the
// encoder scales by the element size). $ra is tied to the writeback $ra_wb.
// These are selected in C++ from POST_INC indexed loads/stores (no pattern).
let Constraints = "$ra = $ra_wb", mayLoad = 1 in {
def LBI_POST  : NDS32Inst<(outs GPR:$rt, GPR:$ra_wb), (ins GPR:$ra, i32imm:$imm),
                          "lbi.bi\t$rt, [$ra], $imm", []>;
def LBSI_POST : NDS32Inst<(outs GPR:$rt, GPR:$ra_wb), (ins GPR:$ra, i32imm:$imm),
                          "lbsi.bi\t$rt, [$ra], $imm", []>;
def LHI_POST  : NDS32Inst<(outs GPR:$rt, GPR:$ra_wb), (ins GPR:$ra, i32imm:$imm),
                          "lhi.bi\t$rt, [$ra], $imm", []>;
def LHSI_POST : NDS32Inst<(outs GPR:$rt, GPR:$ra_wb), (ins GPR:$ra, i32imm:$imm),
                          "lhsi.bi\t$rt, [$ra], $imm", []>;
def LWI_POST  : NDS32Inst<(outs GPR:$rt, GPR:$ra_wb), (ins GPR:$ra, i32imm:$imm),
                          "lwi.bi\t$rt, [$ra], $imm", []>;
}
let Constraints = "$ra = $ra_wb", mayStore = 1 in {
def SBI_POST : NDS32Inst<(outs GPR:$ra_wb), (ins GPR:$rt, GPR:$ra, i32imm:$imm),
                         "sbi.bi\t$rt, [$ra], $imm", []>;
def SHI_POST : NDS32Inst<(outs GPR:$ra_wb), (ins GPR:$rt, GPR:$ra, i32imm:$imm),
                         "shi.bi\t$rt, [$ra], $imm", []>;
def SWI_POST : NDS32Inst<(outs GPR:$ra_wb), (ins GPR:$rt, GPR:$ra, i32imm:$imm),
                         "swi.bi\t$rt, [$ra], $imm", []>;
}

// Any-extending narrow loads (don't care about the high bits): reuse the
// zero-extending byte/halfword loads.
def : Pat<(i32 (extloadi8 addr:$addr)),  (LBI memri8:$addr)>;
def : Pat<(i32 (extloadi16 addr:$addr)), (LHI memri16:$addr)>;
// A 1-bit (i1) load is materialized as a byte load.
def : Pat<(i32 (extloadi1 addr:$addr)),  (LBI memri8:$addr)>;

let isReturn = 1, isTerminator = 1, isBarrier = 1 in
def RET : NDS32Inst<(outs), (ins), "ret", [(NDS32retflag)]> {
  let Inst = 0x4a007820;
}

let isBranch = 1, isTerminator = 1, isBarrier = 1 in
def BR : JF<0x48, (outs), (ins brtarget25:$target), "b\t$target",
            [(br bb:$target)]>;

// Indirect jump (jr $rs): used for jump-table dispatch (brind). op6=0x25,
// $rs in [14:10].
let isBranch = 1, isTerminator = 1, isBarrier = 1, isIndirectBranch = 1 in
def JR : NDS32Inst<(outs), (ins GPR:$rs), "jr\t$rs", [(brind GPR:$rs)]> {
  bits<5> rs;
  let Inst{31-25} = 0x25;
  let Inst{14-10} = rs;
}

def call_target : Operand<i32> { let EncoderMethod = "encodeBr25"; }

let isCall = 1, Defs = [R30] in {
  def JAL : JF<0x49, (outs), (ins call_target:$target), "jal\t$target", []>;
  def JRAL : NDS32Inst<(outs), (ins GPR:$rs), "jral\t$rs", []> {
    bits<5> rs;
    let Inst{31-25} = 0x25;
    let Inst{24-15} = 0x3c0;
    let Inst{14-10} = rs;
    let Inst{9-0} = 1;
  }
}

//===----------------------------------------------------------------------===//
// 16-bit (compressed) instruction forms. These are produced post-RA by the
// NDS32Compress pass from their 32-bit equivalents when the operands fit, for
// ~20-30% smaller .text. They carry no ISel patterns. Size = 2 bytes.
//===----------------------------------------------------------------------===//
class NDS32Inst16<dag outs, dag ins, string asmstr> : Instruction {
  let Namespace = "NDS32";
  let Size = 2;
  let OutOperandList = outs;
  let InOperandList = ins;
  let AsmString = asmstr;
  let Pattern = [];
  field bits<16> Inst;
}

def MOV55   : NDS32Inst16<(outs GPR:$rt), (ins GPR:$ra), "mov55\t$rt, $ra">;
def MOVI55  : NDS32Inst16<(outs GPR:$rt), (ins i32imm:$imm),
                          "movi55\t$rt, $imm">;
let Constraints = "$src = $rt" in {
def ADD45  : NDS32Inst16<(outs GPR:$rt), (ins GPR:$src, GPR:$rb),
                         "add45\t$rt, $rb">;
def ADDI45 : NDS32Inst16<(outs GPR:$rt), (ins GPR:$src, i32imm:$imm),
                         "addi45\t$rt, $imm">;
}
def ADDI333 : NDS32Inst16<(outs GPR:$rt), (ins GPR:$ra, i32imm:$imm),
                          "addi333\t$rt, $ra, $imm">;
def LWI333 : NDS32Inst16<(outs GPR:$rt), (ins GPR:$ra, i32imm:$imm),
                         "lwi333\t$rt, [$ra + $imm]"> { let mayLoad = 1; }
def SWI333 : NDS32Inst16<(outs), (ins GPR:$rt, GPR:$ra, i32imm:$imm),
                         "swi333\t$rt, [$ra + $imm]"> { let mayStore = 1; }

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
def BEQZ : Br17<2, (outs), (ins GPR:$rt, brtarget17:$target),
                 "beqz\t$rt, $target",
                 [(NDS32br_cc SETEQ, GPR:$rt, (i32 0), bb:$target)]>;

def BNEZ : Br17<3, (outs), (ins GPR:$rt, brtarget17:$target),
                 "bnez\t$rt, $target",
                 [(NDS32br_cc SETNE, GPR:$rt, (i32 0), bb:$target)]>;

def BGEZ : Br17<4, (outs), (ins GPR:$rt, brtarget17:$target),
                 "bgez\t$rt, $target",
                 [(NDS32br_cc SETGE, GPR:$rt, (i32 0), bb:$target)]>;

def BLTZ : Br17<5, (outs), (ins GPR:$rt, brtarget17:$target),
                 "bltz\t$rt, $target",
                 [(NDS32br_cc SETLT, GPR:$rt, (i32 0), bb:$target)]>;

def BGTZ : Br17<6, (outs), (ins GPR:$rt, brtarget17:$target),
                 "bgtz\t$rt, $target",
                 [(NDS32br_cc SETGT, GPR:$rt, (i32 0), bb:$target)]>;

def BLEZ : Br17<7, (outs), (ins GPR:$rt, brtarget17:$target),
                 "blez\t$rt, $target",
                 [(NDS32br_cc SETLE, GPR:$rt, (i32 0), bb:$target)]>;

def BEQ : Br15<0, (outs), (ins GPR:$rt, GPR:$ra, brtarget15:$target),
                "beq\t$rt, $ra, $target",
                [(NDS32br_cc SETEQ, GPR:$rt, GPR:$ra, bb:$target)]>;

def BNE : Br15<1, (outs), (ins GPR:$rt, GPR:$ra, brtarget15:$target),
                "bne\t$rt, $ra, $target",
                [(NDS32br_cc SETNE, GPR:$rt, GPR:$ra, bb:$target)]>;
}

// SETHI patterns: NDS32wrapper(tglobaladdr/texternalsym/tconstpool) → SETHI.
def : Pat<(NDS32wrapper tglobaladdr:$imm), (SETHI tglobaladdr:$imm)>;
def : Pat<(NDS32wrapper texternalsym:$imm), (SETHI texternalsym:$imm)>;
def : Pat<(NDS32wrapper tconstpool:$imm), (SETHI tconstpool:$imm)>;
def : Pat<(NDS32wrapper tjumptable:$imm), (SETHI tjumptable:$imm)>;
// TLS (thread-local) symbols use the same sethi/ori address build.
def : Pat<(NDS32wrapper tglobaltlsaddr:$imm), (SETHI tglobaltlsaddr:$imm)>;
def : Pat<(or GPR:$lhs, (NDS32wrapper tglobaltlsaddr:$imm)),
          (ORri GPR:$lhs, tglobaltlsaddr:$imm)>;

// ADDri patterns for global-address lower-half (address computation).
def : Pat<(add GPR:$lhs, (NDS32wrapper tglobaladdr:$imm)),
          (ADDri GPR:$lhs, tglobaladdr:$imm)>;
// ORri form used for the PIC GOT/GOTOFF lower-half (ori, not addi, so the low
// 12 bits are not sign-extended into the high part).
def : Pat<(or GPR:$lhs, (NDS32wrapper tglobaladdr:$imm)),
          (ORri GPR:$lhs, tglobaladdr:$imm)>;
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

//===----------------------------------------------------------------------===//
// Single-precision hardware FPU (AndeStar V3f). f32 lives in FPR32; the ABI
// still passes/returns it in GPRs (softfp), so values cross the GPR/FPR
// boundary via fmtsr/fmfsr (also used for bitcasts and int<->float plumbing).
//===----------------------------------------------------------------------===//
let Predicates = [HasFPU] in {
def FADDS : NDS32Inst<(outs FPR32:$fd), (ins FPR32:$fs1, FPR32:$fs2),
                      "fadds\t$fd, $fs1, $fs2",
                      [(set FPR32:$fd, (fadd FPR32:$fs1, FPR32:$fs2))]>;
def FSUBS : NDS32Inst<(outs FPR32:$fd), (ins FPR32:$fs1, FPR32:$fs2),
                      "fsubs\t$fd, $fs1, $fs2",
                      [(set FPR32:$fd, (fsub FPR32:$fs1, FPR32:$fs2))]>;
def FMULS : NDS32Inst<(outs FPR32:$fd), (ins FPR32:$fs1, FPR32:$fs2),
                      "fmuls\t$fd, $fs1, $fs2",
                      [(set FPR32:$fd, (fmul FPR32:$fs1, FPR32:$fs2))]>;
def FDIVS : NDS32Inst<(outs FPR32:$fd), (ins FPR32:$fs1, FPR32:$fs2),
                      "fdivs\t$fd, $fs1, $fs2",
                      [(set FPR32:$fd, (fdiv FPR32:$fs1, FPR32:$fs2))]>;
def FSQRTS : NDS32Inst<(outs FPR32:$fd), (ins FPR32:$fs),
                       "fsqrts\t$fd, $fs",
                       [(set FPR32:$fd, (fsqrt FPR32:$fs))]>;
def FABSS : NDS32Inst<(outs FPR32:$fd), (ins FPR32:$fs),
                      "fabss\t$fd, $fs",
                      [(set FPR32:$fd, (fabs FPR32:$fs))]>;
// Copy with sign of fs2 / with negated sign of fs2.
def FCPYSS : NDS32Inst<(outs FPR32:$fd), (ins FPR32:$fs1, FPR32:$fs2),
                       "fcpyss\t$fd, $fs1, $fs2",
                       [(set FPR32:$fd, (fcopysign FPR32:$fs1, FPR32:$fs2))]>;
def FCPYNSS : NDS32Inst<(outs FPR32:$fd), (ins FPR32:$fs1, FPR32:$fs2),
                        "fcpynss\t$fd, $fs1, $fs2", []>;
def : Pat<(fneg FPR32:$x), (FCPYNSS FPR32:$x, FPR32:$x)>;

// Conversions: result/source integer bits live in an FPR; move to/from a GPR
// with fmfsr/fmtsr.
def FS2SI : NDS32Inst<(outs FPR32:$fd), (ins FPR32:$fs), "fs2si\t$fd, $fs", []>;
def FS2UI : NDS32Inst<(outs FPR32:$fd), (ins FPR32:$fs), "fs2ui\t$fd, $fs", []>;
def FSI2S : NDS32Inst<(outs FPR32:$fd), (ins FPR32:$fs), "fsi2s\t$fd, $fs", []>;
def FUI2S : NDS32Inst<(outs FPR32:$fd), (ins FPR32:$fs), "fui2s\t$fd, $fs", []>;
def FMFSR : NDS32Inst<(outs GPR:$rt), (ins FPR32:$fs), "fmfsr\t$rt, $fs", []>;
def FMTSR : NDS32Inst<(outs FPR32:$fd), (ins GPR:$rt), "fmtsr\t$rt, $fd", []>;

def : Pat<(i32 (bitconvert FPR32:$x)), (FMFSR FPR32:$x)>;
def : Pat<(f32 (bitconvert GPR:$x)), (FMTSR GPR:$x)>;
def : Pat<(i32 (fp_to_sint FPR32:$x)), (FMFSR (FS2SI FPR32:$x))>;
def : Pat<(i32 (fp_to_uint FPR32:$x)), (FMFSR (FS2UI FPR32:$x))>;
def : Pat<(f32 (sint_to_fp GPR:$x)), (FSI2S (FMTSR GPR:$x))>;
def : Pat<(f32 (uint_to_fp GPR:$x)), (FUI2S (FMTSR GPR:$x))>;

// Loads and stores (word-scaled offset, like lwi/swi).
def FLSI : NDS32Inst<(outs FPR32:$fd), (ins memri:$addr),
                     "flsi\t$fd, [$addr]",
                     [(set FPR32:$fd, (load addr:$addr))]>;
def FSSI : NDS32Inst<(outs), (ins FPR32:$fd, memri:$addr),
                     "fssi\t$fd, [$addr]",
                     [(store FPR32:$fd, addr:$addr)]>;

// Compares produce a 0/1 in an FPR; move it to a GPR boolean with fmfsr.
def FCMPEQS : NDS32Inst<(outs FPR32:$fd), (ins FPR32:$fs1, FPR32:$fs2),
                        "fcmpeqs\t$fd, $fs1, $fs2", []>;
def FCMPLTS : NDS32Inst<(outs FPR32:$fd), (ins FPR32:$fs1, FPR32:$fs2),
                        "fcmplts\t$fd, $fs1, $fs2", []>;
def FCMPLES : NDS32Inst<(outs FPR32:$fd), (ins FPR32:$fs1, FPR32:$fs2),
                        "fcmples\t$fd, $fs1, $fs2", []>;
def : Pat<(i32 (setcc FPR32:$a, FPR32:$b, SETOEQ)), (FMFSR (FCMPEQS $a, $b))>;
def : Pat<(i32 (setcc FPR32:$a, FPR32:$b, SETOLT)), (FMFSR (FCMPLTS $a, $b))>;
def : Pat<(i32 (setcc FPR32:$a, FPR32:$b, SETOLE)), (FMFSR (FCMPLES $a, $b))>;
def : Pat<(i32 (setcc FPR32:$a, FPR32:$b, SETOGT)), (FMFSR (FCMPLTS $b, $a))>;
def : Pat<(i32 (setcc FPR32:$a, FPR32:$b, SETOGE)), (FMFSR (FCMPLES $b, $a))>;
} // Predicates = [HasFPU]
