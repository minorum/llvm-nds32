//===-- NDS32InstrInfo.td - Target description for NDS32 ---*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

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
def brtarget25 : Operand<OtherVT> {
  let EncoderMethod = "encodeBr25";
  let DecoderMethod = "decodeBr25";
}
def brtarget17 : Operand<OtherVT> {
  let EncoderMethod = "encodeBr17";
  let DecoderMethod = "decodeBr17";
}
def brtarget15 : Operand<OtherVT> {
  let EncoderMethod = "encodeBr15";
  let DecoderMethod = "decodeBr15";
}

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

// AsmParser operand classes for the bracketed memory syntax. The parser emits
// the '[' and ']' as literal tokens and the inner "$base + off" / "$base +
// $index << sv" as one Mem / MemRR operand.
def MemAsmOperand : AsmOperandClass {
  let Name = "Mem";
  let RenderMethod = "addMemOperands";
  let PredicateMethod = "isMem";
}
def MemRRAsmOperand : AsmOperandClass {
  let Name = "MemRR";
  let RenderMethod = "addMemRROperands";
  let PredicateMethod = "isMemRR";
}

// I-type 15-bit immediate (carries lo12 symbol fixups via encodeImm15). The
// plain form is zero-extended (andi/ori/xori/bitci); the signed form
// (addi/slti/sltsi) sign-extends on disassembly.
def imm15op : Operand<i32> { let EncoderMethod = "encodeImm15"; }
def simm15op : Operand<i32> {
  let EncoderMethod = "encodeImm15";
  let DecoderMethod = "decodeSImm15";
}
// 20-bit immediate (movi / sethi hi20 fixups). movi sign-extends; sethi uses a
// separate unsigned sethi_imm operand.
def imm20op : Operand<i32> {
  let EncoderMethod = "encodeImm20";
  let DecoderMethod = "decodeSImm20";
}

// Memory operand: base register + constant word-aligned byte offset. The
// EncoderMethod packs base[19:15] and the scaled offset[14:0] into Inst[19:0].
def memri : Operand<i32> {
  let PrintMethod = "printMemOperand";
  let MIOperandInfo = (ops GPR, i32imm);
  let EncoderMethod = "encodeMemWords";
  let DecoderMethod = "decodeMemWords";
  let ParserMatchClass = MemAsmOperand;
}

def memri8 : Operand<i32> {
  let PrintMethod = "printMemOperand";
  let MIOperandInfo = (ops GPR, i32imm);
  let EncoderMethod = "encodeMemBytes";
  let DecoderMethod = "decodeMemBytes";
  let ParserMatchClass = MemAsmOperand;
}

def memri16 : Operand<i32> {
  let PrintMethod = "printMemOperand";
  let MIOperandInfo = (ops GPR, i32imm);
  let EncoderMethod = "encodeMemHalfwords";
  let DecoderMethod = "decodeMemHalfwords";
  let ParserMatchClass = MemAsmOperand;
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

// divsr/divr: quotient in rt, remainder in [9:5], op6=0x20, sub in [4:0].
class DivF<bits<5> sub, dag outs, dag ins, string asmstr, list<dag> pattern>
    : NDS32Inst<outs, ins, asmstr, pattern> {
  bits<5> quo;
  bits<5> rem;
  bits<5> lhs;
  bits<5> rhs;
  let Inst{31-25} = 0x20;
  let Inst{24-20} = quo;
  let Inst{19-15} = lhs;
  let Inst{14-10} = rhs;
  let Inst{9-5} = rem;
  let Inst{4-0} = sub;
}

// Single-precision FPU formats (op6 = 0x35). Three-register and two-register
// (the latter's sub-opcode spans [14:0], so the second source field is opcode).
class FPrrr<bits<10> sub, dag outs, dag ins, string asmstr, list<dag> pattern>
    : NDS32Inst<outs, ins, asmstr, pattern> {
  bits<5> fd;
  bits<5> fs1;
  bits<5> fs2;
  let Inst{31-25} = 0x35;
  let Inst{24-20} = fd;
  let Inst{19-15} = fs1;
  let Inst{14-10} = fs2;
  let Inst{9-0} = sub;
}
class FP2r<bits<15> sub, dag outs, dag ins, string asmstr, list<dag> pattern>
    : NDS32Inst<outs, ins, asmstr, pattern> {
  bits<5> fd;
  bits<5> fs;
  let Inst{31-25} = 0x35;
  let Inst{24-20} = fd;
  let Inst{19-15} = fs;
  let Inst{14-0} = sub;
}

def addr : ComplexPattern<iPTR, 2, "selectMemAddr", [frameindex]>;

// Register-offset addressing: base register + (index << scale), scale in 0..3.
def memrr : Operand<i32> {
  let PrintMethod = "printRegOffsetMem";
  let MIOperandInfo = (ops GPR, GPR, i32imm);
  let EncoderMethod = "encodeRegOffset";
  let DecoderMethod = "decodeRegOffset";
  let ParserMatchClass = MemRRAsmOperand;
}
def regoaddr : ComplexPattern<iPTR, 3, "selectRegOffsetAddr", []>;
// Absolute address reachable from the ROM-fixed $gp (see -nds32-gp-base).
def gpaddr : ComplexPattern<iPTR, 1, "selectGpAddr", []>;

// Post-increment byte increment, scaled to element units by the EncoderMethod.
def postimm_b : Operand<i32> {
  let EncoderMethod = "encodePostByte";
  let DecoderMethod = "decodePostByte";
}
def postimm_h : Operand<i32> {
  let EncoderMethod = "encodePostHalf";
  let DecoderMethod = "decodePostHalf";
}
def postimm_w : Operand<i32> {
  let EncoderMethod = "encodePostWord";
  let DecoderMethod = "decodePostWord";
}
// 16-bit lwi333/swi333 word offset.
def off3words : Operand<i32> {
  let EncoderMethod = "encodeOff3Words";
  let DecoderMethod = "decodeOff3Words";
}
def off3half : Operand<i32> { let DecoderMethod = "decodeOff3Half"; } // lhi333/shi333
def off3byte : Operand<i32> { let DecoderMethod = "decodeOff3Byte"; } // lbi333/sbi333

// 16-bit movi55: 5-bit signed immediate.
def simm5op : Operand<i32> { let DecoderMethod = "decodeSImm5"; }

// Additional 16-bit (Baseline16) operand forms used only for disassembly.
def off7w   : Operand<i32> { let DecoderMethod = "decodeOff7Words"; } // lwi37.sp/swi37.sp
def off6w   : Operand<i32> { let DecoderMethod = "decodeOff6Words"; } // addri36.sp
def simm10op : Operand<i32> { let DecoderMethod = "decodeSImm10"; }   // addi10.sp
def movpiimm : Operand<i32> { let DecoderMethod = "decodeMovpi"; }    // movpi45 (+16 bias)
def gpreven : RegisterOperand<GPR> { let DecoderMethod = "decodeEvenGPR"; } // movd44
def simm11op : Operand<i32> { let DecoderMethod = "decodeSImm11"; }   // beqc/bnec
def off17w   : Operand<i32> {                                          // lwi.gp/swi.gp
  let DecoderMethod = "decodeOff17Words";
  // The operand carries a BYTE displacement (what the disassembler prints);
  // the field holds it scaled to words. Without this the two directions
  // disagree by a factor of four.
  let EncoderMethod = "encodeOff17Words";
}
def off17b   : Operand<i32> { let DecoderMethod = "decodeOff17Byte"; }  // lbsi.gp
// 8-bit PC-relative target (x2) for the 32-bit beqc/bnec (same decode as the
// 16-bit short-branch displacement).
def brtarget8 : Operand<OtherVT> { let DecoderMethod = "decodeBr9"; }

// Register-offset load/store: op6=0x1c, rt, packed base/index/scale in [19:8],
// 8-bit sub-opcode in [7:0].
class RegOffF<bits<8> sub, dag outs, dag ins, string asmstr, list<dag> pattern>
    : NDS32Inst<outs, ins, asmstr, pattern> {
  bits<5> rt;
  bits<12> addr;
  let Inst{31-25} = 0x1c;
  let Inst{24-20} = rt;
  let Inst{19-8} = addr;
  let Inst{7-0} = sub;
}

// Post-increment load/store: op6 selects the form; rt, base ra, 15-bit
// element-scaled increment. The writeback base is a tied output (not encoded).
class PostF<bits<7> op6, dag outs, dag ins, string asmstr, list<dag> pattern>
    : NDS32Inst<outs, ins, asmstr, pattern> {
  bits<5> rt;
  bits<5> ra;
  bits<15> imm;
  let Inst{31-25} = op6;
  let Inst{24-20} = rt;
  let Inst{19-15} = ra;
  let Inst{14-0} = imm;
}

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

def ADDri : ALUi15<0x28, (outs GPR:$rt), (ins GPR:$ra, simm15op:$imm),
                   "addi\t$rt, $ra, $imm",
                   [(set GPR:$rt, (add GPR:$ra, simm15:$imm))]>;

def SUBrr : ALUrrr<0x20, 1, (outs GPR:$rt), (ins GPR:$ra, GPR:$rb),
                   "sub\t$rt, $ra, $rb",
                   [(set GPR:$rt, (sub GPR:$ra, GPR:$rb))]>;

def MULrr : ALUrrr<0x21, 0x24, (outs GPR:$rt), (ins GPR:$ra, GPR:$rb),
                   "mul\t$rt, $ra, $rb",
                   [(set GPR:$rt, (mul GPR:$ra, GPR:$rb))]>;

def DIVSR : DivF<0x16, (outs GPR:$quo, GPR:$rem), (ins GPR:$lhs, GPR:$rhs),
                 "divsr\t$quo, $rem, $lhs, $rhs",
                 [(set GPR:$quo, (sdiv GPR:$lhs, GPR:$rhs)),
                  (set GPR:$rem, (srem GPR:$lhs, GPR:$rhs))]>;

def DIVR : DivF<0x17, (outs GPR:$quo, GPR:$rem), (ins GPR:$lhs, GPR:$rhs),
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
// V3-baseline only: the V2 core (e.g. the MT6785 conn-MCU) traps on bitci as an
// illegal instruction, so the pattern must not be selected below V3.
def bitci_xform : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant(~(uint32_t)N->getZExtValue() & 0x7fff,
                                   SDLoc(N), MVT::i32);
}]>;
def imm_bitci : PatLeaf<(imm), [{
  return isUInt<15>(~(uint32_t)N->getZExtValue());
}], bitci_xform>;
def BITCI : ALUi15<0x33, (outs GPR:$rt), (ins GPR:$ra, imm15op:$imm),
                   "bitci\t$rt, $ra, $imm",
                   [(set GPR:$rt, (and GPR:$ra, imm_bitci:$imm))]>,
                   Requires<[HasV3Ops]>;

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

def SLTI : ALUi15<0x2e, (outs GPR:$rt), (ins GPR:$ra, simm15op:$imm),
                  "slti\t$rt, $ra, $imm",
                  [(set GPR:$rt, (setcc GPR:$ra, simm15:$imm, SETULT))]>;

def SLTSI : ALUi15<0x2f, (outs GPR:$rt), (ins GPR:$ra, simm15op:$imm),
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
def LW_RR : RegOffF<0x02, (outs GPR:$rt), (ins memrr:$addr),
                    "lw\t$rt, [$addr]",
                    [(set GPR:$rt, (load regoaddr:$addr))]>;
def LB_RR : RegOffF<0x00, (outs GPR:$rt), (ins memrr:$addr),
                    "lb\t$rt, [$addr]",
                    [(set GPR:$rt, (zextloadi8 regoaddr:$addr))]>;
def LBS_RR : RegOffF<0x10, (outs GPR:$rt), (ins memrr:$addr),
                     "lbs\t$rt, [$addr]",
                     [(set GPR:$rt, (sextloadi8 regoaddr:$addr))]>;
def LH_RR : RegOffF<0x01, (outs GPR:$rt), (ins memrr:$addr),
                    "lh\t$rt, [$addr]",
                    [(set GPR:$rt, (zextloadi16 regoaddr:$addr))]>;
def LHS_RR : RegOffF<0x11, (outs GPR:$rt), (ins memrr:$addr),
                     "lhs\t$rt, [$addr]",
                     [(set GPR:$rt, (sextloadi16 regoaddr:$addr))]>;
def SW_RR : RegOffF<0x0a, (outs), (ins GPR:$rt, memrr:$addr),
                    "sw\t$rt, [$addr]",
                    [(store GPR:$rt, regoaddr:$addr)]>;
def SB_RR : RegOffF<0x08, (outs), (ins GPR:$rt, memrr:$addr),
                    "sb\t$rt, [$addr]",
                    [(truncstorei8 GPR:$rt, regoaddr:$addr)]>;
def SH_RR : RegOffF<0x09, (outs), (ins GPR:$rt, memrr:$addr),
                    "sh\t$rt, [$addr]",
                    [(truncstorei16 GPR:$rt, regoaddr:$addr)]>;
def : Pat<(i32 (extloadi8 regoaddr:$addr)),  (LB_RR memrr:$addr)>;
def : Pat<(i32 (extloadi16 regoaddr:$addr)), (LH_RR memrr:$addr)>;
def : Pat<(i32 (extloadi1 regoaddr:$addr)),  (LB_RR memrr:$addr)>;

// Post-increment loads/stores: access [$ra], then $ra += $imm (byte units; the
// encoder scales by the element size). $ra is tied to the writeback $ra_wb.
// These are selected in C++ from POST_INC indexed loads/stores (no pattern).
let Constraints = "$ra = $ra_wb", mayLoad = 1 in {
def LBI_POST  : PostF<0x04, (outs GPR:$rt, GPR:$ra_wb), (ins GPR:$ra, postimm_b:$imm),
                      "lbi.bi\t$rt, [$ra], $imm", []>;
def LBSI_POST : PostF<0x14, (outs GPR:$rt, GPR:$ra_wb), (ins GPR:$ra, postimm_b:$imm),
                      "lbsi.bi\t$rt, [$ra], $imm", []>;
def LHI_POST  : PostF<0x05, (outs GPR:$rt, GPR:$ra_wb), (ins GPR:$ra, postimm_h:$imm),
                      "lhi.bi\t$rt, [$ra], $imm", []>;
def LHSI_POST : PostF<0x15, (outs GPR:$rt, GPR:$ra_wb), (ins GPR:$ra, postimm_h:$imm),
                      "lhsi.bi\t$rt, [$ra], $imm", []>;
def LWI_POST  : PostF<0x06, (outs GPR:$rt, GPR:$ra_wb), (ins GPR:$ra, postimm_w:$imm),
                      "lwi.bi\t$rt, [$ra], $imm", []>;
}
let Constraints = "$ra = $ra_wb", mayStore = 1 in {
def SBI_POST : PostF<0x0c, (outs GPR:$ra_wb), (ins GPR:$rt, GPR:$ra, postimm_b:$imm),
                     "sbi.bi\t$rt, [$ra], $imm", []>;
def SHI_POST : PostF<0x0d, (outs GPR:$ra_wb), (ins GPR:$rt, GPR:$ra, postimm_h:$imm),
                     "shi.bi\t$rt, [$ra], $imm", []>;
def SWI_POST : PostF<0x0e, (outs GPR:$ra_wb), (ins GPR:$rt, GPR:$ra, postimm_w:$imm),
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

// The Andes toolchain (and the AndeStar ISA) name this unconditional jump "j";
// match it so disassembly is faithful for reverse-engineering. "b" stays
// accepted as an input alias for backward compatibility.
let isBranch = 1, isTerminator = 1, isBarrier = 1 in
def BR : JF<0x48, (outs), (ins brtarget25:$target), "j\t$target",
            [(br bb:$target)]>;
// Emit=0: "b" is accepted on input only; disassembly prints the canonical "j".
def : InstAlias<"b\t$target", (BR brtarget25:$target), 0>;

// Indirect jump (jr $rs): used for jump-table dispatch (brind). op6=0x25,
// $rs in [14:10].
let isBranch = 1, isTerminator = 1, isBarrier = 1, isIndirectBranch = 1 in
def JR : NDS32Inst<(outs), (ins GPR:$rs), "jr\t$rs", [(brind GPR:$rs)]> {
  bits<5> rs;
  let Inst{31-25} = 0x25;
  let Inst{14-10} = rs;
}

def call_target : Operand<i32> {
  let EncoderMethod = "encodeBr25";
  let DecoderMethod = "decodeBr25";
}

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

def MOV55   : NDS32Inst16<(outs GPR:$rt), (ins GPR:$ra), "mov55\t$rt, $ra"> {
  bits<5> rt; bits<5> ra;
  let Inst{15-10} = 0x20; let Inst{9-5} = rt; let Inst{4-0} = ra;
}
def MOVI55  : NDS32Inst16<(outs GPR:$rt), (ins simm5op:$imm),
                          "movi55\t$rt, $imm"> {
  bits<5> rt; bits<5> imm;
  let Inst{15-10} = 0x21; let Inst{9-5} = rt; let Inst{4-0} = imm;
}
// add45/addi45: $rt is a 4-bit field (Inst[8:5], GPR4 subset, reg->code remapped
// by encodeGPR4); the opcode occupies Inst[15:9]. add45 takes a full 5-bit $rb;
// addi45 a 5-bit unsigned immediate. $rt is tied (read-modify-write).
let Constraints = "$src = $rt" in {
def ADD45  : NDS32Inst16<(outs gpr4:$rt), (ins gpr4:$src, GPR:$rb),
                         "add45\t$rt, $rb"> {
  bits<4> rt; bits<5> rb;
  let Inst{15-9} = 0x44; let Inst{8-5} = rt; let Inst{4-0} = rb;
}
def ADDI45 : NDS32Inst16<(outs gpr4:$rt), (ins gpr4:$src, i32imm:$imm),
                         "addi45\t$rt, $imm"> {
  bits<4> rt; bits<5> imm;
  let Inst{15-9} = 0x46; let Inst{8-5} = rt; let Inst{4-0} = imm;
}
}
def ADDI333 : NDS32Inst16<(outs GPR:$rt), (ins GPR:$ra, i32imm:$imm),
                          "addi333\t$rt, $ra, $imm"> {
  bits<3> rt; bits<3> ra; bits<3> imm;
  let Inst{15-9} = 0x4e; let Inst{8-6} = rt; let Inst{5-3} = ra; let Inst{2-0} = imm;
}
def LWI333 : NDS32Inst16<(outs GPR:$rt), (ins GPR:$ra, off3words:$imm),
                         "lwi333\t$rt, [$ra + $imm]"> {
  bits<3> rt; bits<3> ra; bits<3> imm;
  let mayLoad = 1;
  let Inst{15-9} = 0x50; let Inst{8-6} = rt; let Inst{5-3} = ra; let Inst{2-0} = imm;
}
def SWI333 : NDS32Inst16<(outs), (ins GPR:$rt, GPR:$ra, off3words:$imm),
                         "swi333\t$rt, [$ra + $imm]"> {
  bits<3> rt; bits<3> ra; bits<3> imm;
  let mayStore = 1;
  let Inst{15-9} = 0x54; let Inst{8-6} = rt; let Inst{5-3} = ra; let Inst{2-0} = imm;
}

// --- Additional Baseline16 instructions: disassembly coverage only (no codegen
// pattern). Encodings verified against the Andes nds32be-elf-objdump via
// scripts/diff-disasm.sh. These are the highest-frequency 16-bit forms emitted
// by GCC that the codegen subset did not model; less common forms (reg-list
// lmw/smw, beqc/bnec, gp-relative, the 33 ALU group) are left to graceful
// degradation (suggestBytesToSkip).
def NOP16 : NDS32Inst16<(outs), (ins), "nop16"> { let Inst{15-0} = 0x9200; }

let isReturn = 1, isTerminator = 1, isBarrier = 1 in
def RET5 : NDS32Inst16<(outs), (ins GPR:$rb), "ret5\t$rb"> {
  bits<5> rb;
  let Inst{15-5} = 0x6ec; let Inst{4-0} = rb;
}

// In-place (read-modify-write) 16-bit ALU forms ($rt is tied).
let Constraints = "$src = $rt" in {
def SUB45 : NDS32Inst16<(outs gpr4:$rt), (ins gpr4:$src, GPR:$rb),
                        "sub45\t$rt, $rb"> {
  bits<4> rt; bits<5> rb;
  let Inst{15-9} = 0x45; let Inst{8-5} = rt; let Inst{4-0} = rb;
}
def SUBI45 : NDS32Inst16<(outs gpr4:$rt), (ins gpr4:$src, i32imm:$imm),
                         "subi45\t$rt, $imm"> {
  bits<4> rt; bits<5> imm;
  let Inst{15-9} = 0x47; let Inst{8-5} = rt; let Inst{4-0} = imm;
}
def SRLI45 : NDS32Inst16<(outs gpr4:$rt), (ins gpr4:$src, i32imm:$sa),
                         "srli45\t$rt, $sa"> {
  bits<4> rt; bits<5> sa;
  let Inst{15-9} = 0x49; let Inst{8-5} = rt; let Inst{4-0} = sa;
}
}

def SLLI333 : NDS32Inst16<(outs GPR:$rt), (ins GPR:$ra, i32imm:$sa),
                          "slli333\t$rt, $ra, $sa"> {
  bits<3> rt; bits<3> ra; bits<3> sa;
  let Inst{15-9} = 0x4a; let Inst{8-6} = rt; let Inst{5-3} = ra; let Inst{2-0} = sa;
}

def MOVPI45 : NDS32Inst16<(outs gpr4:$rt), (ins movpiimm:$imm),
                          "movpi45\t$rt, $imm"> {
  bits<4> rt; bits<5> imm;
  let Inst{15-9} = 0x7d; let Inst{8-5} = rt; let Inst{4-0} = imm;
}

def MOVD44 : NDS32Inst16<(outs gpreven:$rt), (ins gpreven:$rs),
                         "movd44\t$rt, $rs"> {
  bits<4> rt; bits<4> rs;
  let Inst{15-8} = 0xfd; let Inst{7-4} = rt; let Inst{3-0} = rs;
}

// SP-relative word load/store: 3-bit reg, 7-bit word offset (bit7 = store).
def LWI37SP : NDS32Inst16<(outs GPR:$rt), (ins off7w:$off),
                          "lwi37.sp\t$rt, [+ $off]"> {
  bits<3> rt; bits<7> off;
  let mayLoad = 1;
  let Inst{15-11} = 0x1e; let Inst{10-8} = rt; let Inst{7} = 0; let Inst{6-0} = off;
}
def SWI37SP : NDS32Inst16<(outs), (ins GPR:$rt, off7w:$off),
                          "swi37.sp\t$rt, [+ $off]"> {
  bits<3> rt; bits<7> off;
  let mayStore = 1;
  let Inst{15-11} = 0x1e; let Inst{10-8} = rt; let Inst{7} = 1; let Inst{6-0} = off;
}

def ADDI10SP : NDS32Inst16<(outs), (ins simm10op:$imm), "addi10.sp\t$imm"> {
  bits<10> imm;
  let Inst{15-10} = 0x3b; let Inst{9-0} = imm;
}
def ADDRI36SP : NDS32Inst16<(outs GPR:$rt), (ins off6w:$off),
                            "addri36.sp\t$rt, $off"> {
  bits<3> rt; bits<6> off;
  let Inst{15-9} = 0x58; let Inst{8-6} = rt; let Inst{5-0} = off;
}
def LWI450 : NDS32Inst16<(outs gpr4:$rt), (ins GPR:$ra), "lwi450\t$rt, [$ra]"> {
  bits<4> rt; bits<5> ra;
  let mayLoad = 1;
  let Inst{15-9} = 0x5a; let Inst{8-5} = rt; let Inst{4-0} = ra;
}

// 32-bit subri (reverse subtract immediate): rt = imm15 - ra.
def SUBri : ALUi15<0x29, (outs GPR:$rt), (ins GPR:$ra, simm15op:$imm),
                   "subri\t$rt, $ra, $imm", []>;

def SWI450 : NDS32Inst16<(outs), (ins gpr4:$rt, GPR:$ra), "swi450\t$rt, [$ra]"> {
  bits<4> rt; bits<5> ra;
  let mayStore = 1;
  let Inst{15-9} = 0x5b; let Inst{8-5} = rt; let Inst{4-0} = ra;
}
let Constraints = "$src = $rt" in
def SRAI45 : NDS32Inst16<(outs gpr4:$rt), (ins gpr4:$src, i32imm:$sa),
                         "srai45\t$rt, $sa"> {
  bits<4> rt; bits<5> sa;
  let Inst{15-9} = 0x48; let Inst{8-5} = rt; let Inst{4-0} = sa;
}
def SUBI333 : NDS32Inst16<(outs GPR:$rt), (ins GPR:$ra, i32imm:$imm),
                          "subi333\t$rt, $ra, $imm"> {
  bits<3> rt; bits<3> ra; bits<3> imm;
  let Inst{15-9} = 0x4f; let Inst{8-6} = rt; let Inst{5-3} = ra; let Inst{2-0} = imm;
}
// 16-bit two-register ALU group (major 0x7f, operation in the 3-bit sub field).
class ALU33<bits<3> sub, string asmstr>
    : NDS32Inst16<(outs GPR:$rt), (ins GPR:$ra), asmstr> {
  bits<3> rt; bits<3> ra;
  let Inst{15-9} = 0x7f; let Inst{8-6} = rt; let Inst{5-3} = ra; let Inst{2-0} = sub;
}
def NEG33 : ALU33<2, "neg33\t$rt, $ra">;
def NOT33 : ALU33<3, "not33\t$rt, $ra">;
def MUL33 : ALU33<4, "mul33\t$rt, $ra">;
def XOR33 : ALU33<5, "xor33\t$rt, $ra">;
def AND33 : ALU33<6, "and33\t$rt, $ra">;
def OR33  : ALU33<7, "or33\t$rt, $ra">;

// 16-bit unary "33" group (major 0x4b, operation in the 3-bit sub field).
class Ext33<bits<3> sub, string asmstr>
    : NDS32Inst16<(outs GPR:$rt), (ins GPR:$ra), asmstr> {
  bits<3> rt; bits<3> ra;
  let Inst{15-9} = 0x4b; let Inst{8-6} = rt; let Inst{5-3} = ra; let Inst{2-0} = sub;
}
def ZEB33  : Ext33<0, "zeb33\t$rt, $ra">;
def ZEH33  : Ext33<1, "zeh33\t$rt, $ra">;
def SEB33  : Ext33<2, "seb33\t$rt, $ra">;
def SEH33  : Ext33<3, "seh33\t$rt, $ra">;
def XLSB33 : Ext33<4, "xlsb33\t$rt, $ra">;
def X11B33 : Ext33<5, "x11b33\t$rt, $ra">;
// Same 0x4b major, but [5:3] is a 3-bit immediate instead of a register.
class Ext33i<bits<3> sub, string asmstr>
    : NDS32Inst16<(outs GPR:$rt), (ins i32imm:$imm), asmstr> {
  bits<3> rt; bits<3> imm;
  let Inst{15-9} = 0x4b; let Inst{8-6} = rt; let Inst{5-3} = imm; let Inst{2-0} = sub;
}
def BMSKI33 : Ext33i<6, "bmski33\t$rt, $imm">;
def FEXTI33 : Ext33i<7, "fexti33\t$rt, $imm">;

// 16-bit "333" three-register ALU (rt = ra op rb).
class Alu333<bits<7> op, string asmstr>
    : NDS32Inst16<(outs GPR:$rt), (ins GPR:$ra, GPR:$rb), asmstr> {
  bits<3> rt; bits<3> ra; bits<3> rb;
  let Inst{15-9} = op; let Inst{8-6} = rt; let Inst{5-3} = ra; let Inst{2-0} = rb;
}
def ADD333 : Alu333<0x4c, "add333\t$rt, $ra, $rb">;
def SUB333 : Alu333<0x4d, "sub333\t$rt, $ra, $rb">;

// 16-bit "333" narrow loads/stores (rt, [ra + scaled off3]).
class Mem333<bits<7> op, Operand off, string asmstr, bit ld>
    : NDS32Inst16<(outs), (ins GPR:$rt, GPR:$ra, off:$imm), asmstr> {
  bits<3> rt; bits<3> ra; bits<3> imm;
  let mayLoad = ld; let mayStore = !not(ld);
  let Inst{15-9} = op; let Inst{8-6} = rt; let Inst{5-3} = ra; let Inst{2-0} = imm;
}
def LHI333 : Mem333<0x52, off3half, "lhi333\t$rt, [$ra + $imm]", 1>;
def LBI333 : Mem333<0x53, off3byte, "lbi333\t$rt, [$ra + $imm]", 1>;
def SHI333 : Mem333<0x56, off3half, "shi333\t$rt, [$ra + $imm]", 0>;
def SBI333 : Mem333<0x57, off3byte, "sbi333\t$rt, [$ra + $imm]", 0>;
let Constraints = "$ra = $ra_wb", mayStore = 1 in
def SWI333_BI : NDS32Inst16<(outs GPR:$ra_wb),
                            (ins GPR:$rt, GPR:$ra, off3words:$imm),
                            "swi333.bi\t$rt, [$ra], $imm"> {
  bits<3> rt; bits<3> ra; bits<3> imm;
  let Inst{15-9} = 0x55; let Inst{8-6} = rt; let Inst{5-3} = ra; let Inst{2-0} = imm;
}

// 16-bit jump-and-link-register (jral5 $rb): op + 5-bit register.
let isCall = 1, Defs = [R30] in
def JRAL5 : NDS32Inst16<(outs), (ins GPR:$rb), "jral5\t$rb"> {
  bits<5> rb;
  let Inst{15-5} = 0x6e9; let Inst{4-0} = rb;
}

// 32-bit iret: op6=0x32, sub [4:0]=0x04. Exception return -- restores $psw from
// $ipsw and jumps to $ipc atomically. Needed to write a context switch (the
// saved context replaces the current one, so this is not a `ret`); the
// disassembler previously rejected 64 00 00 04 because nothing defined it.
let isTerminator = 1, isBarrier = 1, isReturn = 1, hasSideEffects = 1 in
def IRET : NDS32Inst<(outs), (ins), "iret", []> {
  let Inst{31-25} = 0x32; let Inst{24-20} = 0;
  let Inst{19-5} = 0;     let Inst{4-0} = 0x04;
}

// 32-bit syscall: op6=0x32, 15-bit service id [19:5], sub [4:0]=0x0b.
def SYSCALL : NDS32Inst<(outs), (ins i32imm:$swid), "syscall\t$swid", []> {
  bits<15> swid;
  let Inst{31-25} = 0x32; let Inst{24-20} = 0; let Inst{19-5} = swid;
  let Inst{4-0} = 0x0b;
}
let Constraints = "$ra = $ra_wb", mayLoad = 1 in
def LWI333_BI : NDS32Inst16<(outs GPR:$rt, GPR:$ra_wb),
                            (ins GPR:$ra, off3words:$imm),
                            "lwi333.bi\t$rt, [$ra], $imm"> {
  bits<3> rt; bits<3> ra; bits<3> imm;
  let Inst{15-9} = 0x51; let Inst{8-6} = rt; let Inst{5-3} = ra; let Inst{2-0} = imm;
}

// 32-bit branch-compare-immediate: op6=0x2d, rt[24:20], eq/ne bit[19],
// signed 11-bit compare value [18:8], 8-bit PC-relative disp [7:0] (x2).
class BcF<bits<1> ne, dag outs, dag ins, string asmstr>
    : NDS32Inst<outs, ins, asmstr, []> {
  bits<5> rt; bits<11> imm; bits<8> target;
  let Inst{31-25} = 0x2d; let Inst{24-20} = rt; let Inst{19} = ne;
  let Inst{18-8} = imm; let Inst{7-0} = target;
}
let isBranch = 1, isTerminator = 1 in {
def BEQC : BcF<0, (outs), (ins GPR:$rt, simm11op:$imm, brtarget8:$target),
                "beqc\t$rt, $imm, $target">;
def BNEC : BcF<1, (outs), (ins GPR:$rt, simm11op:$imm, brtarget8:$target),
                "bnec\t$rt, $imm, $target">;
}

// 32-bit gp-relative word load/store: op6=0x1e, rt[24:20], sub[19:17],
// signed 17-bit word offset [16:0] (x4).
class GpF<bits<3> sub, dag outs, dag ins, string asmstr>
    : NDS32Inst<outs, ins, asmstr, []> {
  bits<5> rt; bits<17> off;
  let Inst{31-25} = 0x1e; let Inst{24-20} = rt; let Inst{19-17} = sub;
  let Inst{16-0} = off;
}
def LWI_GP : GpF<6, (outs GPR:$rt), (ins off17w:$off), "lwi.gp\t$rt, [+ $off]"> {
  let mayLoad = 1;
}
def SWI_GP : GpF<7, (outs), (ins GPR:$rt, off17w:$off), "swi.gp\t$rt, [+ $off]"> {
  let mayStore = 1;
}

// Absolute loads/stores through the fixed $gp. Only selected when
// -nds32-gp-base names the runtime $gp and the address is in range and
// word-aligned (selectGpAddr enforces both); otherwise the generic
// sethi/ori + [reg + 0] path applies unchanged.
// AddedComplexity beats LWI/SWI's own `addr` patterns, which match any address
// and would otherwise always win.
let AddedComplexity = 20 in {
def : Pat<(i32 (load gpaddr:$off)), (LWI_GP off17w:$off)>;
def : Pat<(store GPR:$rt, gpaddr:$off), (SWI_GP GPR:$rt, off17w:$off)>;
}

// 32-bit ALU2 group (op6=0x21): 3-register max/min and bit set/clear/test.
def MAX  : ALUrrr<0x21, 0x000, (outs GPR:$rt), (ins GPR:$ra, GPR:$rb),
                  "max\t$rt, $ra, $rb", []>;
def MIN  : ALUrrr<0x21, 0x001, (outs GPR:$rt), (ins GPR:$ra, GPR:$rb),
                  "min\t$rt, $ra, $rb", []>;
def BSET : ALUsa<0x21, 0x008, (outs GPR:$rt), (ins GPR:$ra, i32imm:$sa),
                 "bset\t$rt, $ra, $sa", []>;
def BCLR : ALUsa<0x21, 0x009, (outs GPR:$rt), (ins GPR:$ra, i32imm:$sa),
                 "bclr\t$rt, $ra, $sa", []>;
def BTST : ALUsa<0x21, 0x00b, (outs GPR:$rt), (ins GPR:$ra, i32imm:$sa),
                 "btst\t$rt, $ra, $sa", []>;

// 32-bit load/store-multiple (op6=0x1d): rb[24:20], ra(base)[19:15],
// re[14:10], enable4[9:6], addressing-mode sub[5:0] (bit5 = store). The set of
// registers transferred is rb..re plus the $fp/$gp/$lp/$sp bits in enable4
// (Andes prints that set as a trailing "! {...}" comment, derived info).
class LsmwF<bits<6> sub, dag outs, dag ins, string asmstr>
    : NDS32Inst<outs, ins, asmstr, []> {
  bits<5> rb; bits<5> ra; bits<5> re; bits<4> en;
  let Inst{31-25} = 0x1d; let Inst{24-20} = rb; let Inst{19-15} = ra;
  let Inst{14-10} = re; let Inst{9-6} = en; let Inst{5-0} = sub;
}
let mayLoad = 1 in {
def LMW_BI  : LsmwF<0x00, (outs), (ins GPR:$rb, GPR:$ra, GPR:$re, i32imm:$en),
                    "lmw.bi\t$rb, [$ra], $re, $en">;
def LMW_BIM : LsmwF<0x04, (outs), (ins GPR:$rb, GPR:$ra, GPR:$re, i32imm:$en),
                    "lmw.bim\t$rb, [$ra], $re, $en">;
def LMW_AIM : LsmwF<0x14, (outs), (ins GPR:$rb, GPR:$ra, GPR:$re, i32imm:$en),
                    "lmw.aim\t$rb, [$ra], $re, $en">;
}
let mayStore = 1 in {
def SMW_BI  : LsmwF<0x20, (outs), (ins GPR:$rb, GPR:$ra, GPR:$re, i32imm:$en),
                    "smw.bi\t$rb, [$ra], $re, $en">;
def SMW_BIM : LsmwF<0x24, (outs), (ins GPR:$rb, GPR:$ra, GPR:$re, i32imm:$en),
                    "smw.bim\t$rb, [$ra], $re, $en">;
def SMW_ADM : LsmwF<0x3c, (outs), (ins GPR:$rb, GPR:$ra, GPR:$re, i32imm:$en),
                    "smw.adm\t$rb, [$ra], $re, $en">;
}

// --- Final long-tail coverage (rare forms; verified vs Andes). ---
// 32-bit 3-register ALU2 ops.
def NOR     : ALUrrr<0x20, 0x005, (outs GPR:$rt), (ins GPR:$ra, GPR:$rb),
                     "nor\t$rt, $ra, $rb", []>;
def BITC    : ALUrrr<0x20, 0x012, (outs GPR:$rt), (ins GPR:$ra, GPR:$rb),
                     "bitc\t$rt, $ra, $rb", []>;
def MULR64  : ALUrrr<0x21, 0x069, (outs GPR:$rt), (ins GPR:$ra, GPR:$rb),
                     "mulr64\t$rt, $ra, $rb", []>;
def MULSR64 : ALUrrr<0x21, 0x068, (outs GPR:$rt), (ins GPR:$ra, GPR:$rb),
                     "mulsr64\t$rt, $ra, $rb", []>;
def BTGL    : ALUsa<0x21, 0x00a, (outs GPR:$rt), (ins GPR:$ra, i32imm:$sa),
                    "btgl\t$rt, $ra, $sa", []>;
// 32-bit gp-relative signed byte load (op6=0x17, sub[19:17]=4, off17 unscaled).
def LBSI_GP : NDS32Inst<(outs GPR:$rt), (ins off17b:$off), "lbsi.gp\t$rt, [+ $off]",
                        []> {
  bits<5> rt; bits<17> off;
  let mayLoad = 1;
  let Inst{31-25} = 0x17; let Inst{24-20} = rt; let Inst{19-17} = 4;
  let Inst{16-0} = off;
}
// 32-bit reg-offset post-increment store byte (op6=0x1c, sub=0x0c).
def SB_BI : RegOffF<0x0c, (outs), (ins GPR:$rt, memrr:$addr),
                    "sb.bi\t$rt, $addr", []> { let mayStore = 1; }

// 16-bit jr5-family: add5.pc adds PC to a register.
def ADD5PC : NDS32Inst16<(outs), (ins GPR:$rb), "add5.pc\t$rb"> {
  bits<5> rb;
  let Inst{15-5} = 0x6ed; let Inst{4-0} = rb;
}
// 16-bit short compare-branches beqs38/bnes38 (rt vs implied, 8-bit disp).
let isBranch = 1, isTerminator = 1 in {
def BEQS38 : NDS32Inst16<(outs), (ins GPR:$rt, brtarget8:$target),
                         "beqs38\t$rt, $target"> {
  bits<3> rt; bits<8> target;
  let Inst{15-11} = 0x1a; let Inst{10-8} = rt; let Inst{7-0} = target;
}
def BNES38 : NDS32Inst16<(outs), (ins GPR:$rt, brtarget8:$target),
                         "bnes38\t$rt, $target"> {
  bits<3> rt; bits<8> target;
  let Inst{15-11} = 0x1b; let Inst{10-8} = rt; let Inst{7-0} = target;
}
}

// 16-bit short branches. The 8-bit displacement is PC-relative (scaled by 2),
// giving a +/-256B range; out-of-range forms are grown to their 32-bit
// equivalents (BEQZ/BNEZ/BR) by the assembler's relaxation pass. beqz38/bnez38
// test a 3-bit register ($r0-$r7); the compress pass only emits them for that
// subset.
def brtarget9 : Operand<OtherVT> {
  let EncoderMethod = "encodeBr9";
  let DecoderMethod = "decodeBr9";
}

let isBranch = 1, isTerminator = 1 in {
def BEQZ38 : NDS32Inst16<(outs), (ins GPR:$rt, brtarget9:$target),
                         "beqz38\t$rt, $target"> {
  bits<3> rt; bits<8> target;
  let Inst{15-11} = 0x18; let Inst{10-8} = rt; let Inst{7-0} = target;
}
def BNEZ38 : NDS32Inst16<(outs), (ins GPR:$rt, brtarget9:$target),
                         "bnez38\t$rt, $target"> {
  bits<3> rt; bits<8> target;
  let Inst{15-11} = 0x19; let Inst{10-8} = rt; let Inst{7-0} = target;
}
}
let isBranch = 1, isTerminator = 1, isBarrier = 1 in
def J8 : NDS32Inst16<(outs), (ins brtarget9:$target), "j8\t$target"> {
  bits<8> target;
  let Inst{15-8} = 0xd5; let Inst{7-0} = target;
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

// "mov rt, ra" is the customary NDS32 assembler alias for "ori rt, ra, 0".
def : InstAlias<"mov $rt, $ra", (ORri GPR:$rt, GPR:$ra, 0)>;

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
def FADDS : FPrrr<0x000, (outs FPR32:$fd), (ins FPR32:$fs1, FPR32:$fs2),
                  "fadds\t$fd, $fs1, $fs2",
                  [(set FPR32:$fd, (fadd FPR32:$fs1, FPR32:$fs2))]>;
def FSUBS : FPrrr<0x040, (outs FPR32:$fd), (ins FPR32:$fs1, FPR32:$fs2),
                  "fsubs\t$fd, $fs1, $fs2",
                  [(set FPR32:$fd, (fsub FPR32:$fs1, FPR32:$fs2))]>;
def FMULS : FPrrr<0x300, (outs FPR32:$fd), (ins FPR32:$fs1, FPR32:$fs2),
                  "fmuls\t$fd, $fs1, $fs2",
                  [(set FPR32:$fd, (fmul FPR32:$fs1, FPR32:$fs2))]>;
def FDIVS : FPrrr<0x340, (outs FPR32:$fd), (ins FPR32:$fs1, FPR32:$fs2),
                  "fdivs\t$fd, $fs1, $fs2",
                  [(set FPR32:$fd, (fdiv FPR32:$fs1, FPR32:$fs2))]>;
def FSQRTS : FP2r<0x07c0, (outs FPR32:$fd), (ins FPR32:$fs),
                  "fsqrts\t$fd, $fs",
                  [(set FPR32:$fd, (fsqrt FPR32:$fs))]>;
def FABSS : FP2r<0x17c0, (outs FPR32:$fd), (ins FPR32:$fs),
                 "fabss\t$fd, $fs",
                 [(set FPR32:$fd, (fabs FPR32:$fs))]>;
// Copy with sign of fs2 / with negated sign of fs2.
def FCPYSS : FPrrr<0x0c0, (outs FPR32:$fd), (ins FPR32:$fs1, FPR32:$fs2),
                   "fcpyss\t$fd, $fs1, $fs2",
                   [(set FPR32:$fd, (fcopysign FPR32:$fs1, FPR32:$fs2))]>;
def FCPYNSS : FPrrr<0x080, (outs FPR32:$fd), (ins FPR32:$fs1, FPR32:$fs2),
                    "fcpynss\t$fd, $fs1, $fs2", []>;
def : Pat<(fneg FPR32:$x), (FCPYNSS FPR32:$x, FPR32:$x)>;

// Conversions: result/source integer bits live in an FPR; move to/from a GPR
// with fmfsr/fmtsr.
def FS2SI : FP2r<0x63c0, (outs FPR32:$fd), (ins FPR32:$fs), "fs2si\t$fd, $fs", []>;
def FS2UI : FP2r<0x43c0, (outs FPR32:$fd), (ins FPR32:$fs), "fs2ui\t$fd, $fs", []>;
def FSI2S : FP2r<0x33c0, (outs FPR32:$fd), (ins FPR32:$fs), "fsi2s\t$fd, $fs", []>;
def FUI2S : FP2r<0x23c0, (outs FPR32:$fd), (ins FPR32:$fs), "fui2s\t$fd, $fs", []>;
//===----------------------------------------------------------------------===//
// System registers: mfsr/mtsr.
//
// NOT the floating-point fmfsr/fmtsr below — different opcode entirely. Both
// take a named system register whose 15-bit SRIDX is the register's HWEncoding
// (see NDS32SysRegs.td, generated from binutils ground truth). hasSideEffects
// keeps them from being reordered or dropped: writing $psw / a breakpoint
// register is exactly the observable effect wanted.
//
// Used from `rom-rs` inline asm (subsystems/blob_romcall_a.rs reconstructs the
// stock sysreg-write ladder), so the asm parser must accept every name.
//===----------------------------------------------------------------------===//
let hasSideEffects = 1 in {
def MFSR : NDS32Inst<(outs GPR:$rt), (ins SR:$sr), "mfsr\t$rt, $sr", []> {
  bits<5> rt;
  bits<15> sr;
  let Inst{31-25} = 0x32;
  let Inst{24-20} = rt;
  let Inst{19-5} = sr;
  let Inst{4-0} = 2;
}
def MTSR : NDS32Inst<(outs), (ins GPR:$rt, SR:$sr), "mtsr\t$rt, $sr", []> {
  bits<5> rt;
  bits<15> sr;
  let Inst{31-25} = 0x32;
  let Inst{24-20} = rt;
  let Inst{19-5} = sr;
  let Inst{4-0} = 3;
}
}

def FMFSR : NDS32Inst<(outs GPR:$rt), (ins FPR32:$fs), "fmfsr\t$rt, $fs", []> {
  bits<5> rt;
  bits<5> fs;
  let Inst{31-25} = 0x35;
  let Inst{24-20} = rt;
  let Inst{19-15} = fs;
  let Inst{14-0} = 1;
}
def FMTSR : NDS32Inst<(outs FPR32:$fd), (ins GPR:$rt), "fmtsr\t$rt, $fd", []> {
  bits<5> fd;
  bits<5> rt;
  let Inst{31-25} = 0x35;
  let Inst{24-20} = rt;
  let Inst{19-15} = fd;
  let Inst{14-0} = 9;
}

def : Pat<(i32 (bitconvert FPR32:$x)), (FMFSR FPR32:$x)>;
def : Pat<(f32 (bitconvert GPR:$x)), (FMTSR GPR:$x)>;
def : Pat<(i32 (fp_to_sint FPR32:$x)), (FMFSR (FS2SI FPR32:$x))>;
def : Pat<(i32 (fp_to_uint FPR32:$x)), (FMFSR (FS2UI FPR32:$x))>;
def : Pat<(f32 (sint_to_fp GPR:$x)), (FSI2S (FMTSR GPR:$x))>;
def : Pat<(f32 (uint_to_fp GPR:$x)), (FUI2S (FMTSR GPR:$x))>;

// Loads and stores (word-scaled offset, like lwi/swi).
def FLSI : MemF<0x18, (outs FPR32:$rt), (ins memri:$addr),
                "flsi\t$rt, [$addr]",
                [(set FPR32:$rt, (load addr:$addr))]>;
def FSSI : MemF<0x19, (outs), (ins FPR32:$rt, memri:$addr),
                "fssi\t$rt, [$addr]",
                [(store FPR32:$rt, addr:$addr)]>;

// Compares produce a 0/1 in an FPR; move it to a GPR boolean with fmfsr.
def FCMPEQS : FPrrr<0x004, (outs FPR32:$fd), (ins FPR32:$fs1, FPR32:$fs2),
                    "fcmpeqs\t$fd, $fs1, $fs2", []>;
def FCMPLTS : FPrrr<0x084, (outs FPR32:$fd), (ins FPR32:$fs1, FPR32:$fs2),
                    "fcmplts\t$fd, $fs1, $fs2", []>;
def FCMPLES : FPrrr<0x104, (outs FPR32:$fd), (ins FPR32:$fs1, FPR32:$fs2),
                    "fcmples\t$fd, $fs1, $fs2", []>;
def : Pat<(i32 (setcc FPR32:$a, FPR32:$b, SETOEQ)), (FMFSR (FCMPEQS $a, $b))>;
def : Pat<(i32 (setcc FPR32:$a, FPR32:$b, SETOLT)), (FMFSR (FCMPLTS $a, $b))>;
def : Pat<(i32 (setcc FPR32:$a, FPR32:$b, SETOLE)), (FMFSR (FCMPLES $a, $b))>;
def : Pat<(i32 (setcc FPR32:$a, FPR32:$b, SETOGT)), (FMFSR (FCMPLTS $b, $a))>;
def : Pat<(i32 (setcc FPR32:$a, FPR32:$b, SETOGE)), (FMFSR (FCMPLES $b, $a))>;
} // Predicates = [HasFPU]
