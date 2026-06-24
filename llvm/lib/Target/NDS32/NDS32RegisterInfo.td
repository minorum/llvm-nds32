class NDS32Reg<string n, bits<5> num> : Register<n> {
  let Namespace = "NDS32";
  let HWEncoding{4-0} = num;
}

// General Purpose Registers. The numeric ($rN) name is primary (keeps parsing
// and codegen stable); the InstPrinter substitutes the ABI names $fp/$gp/$lp/$sp
// for r28-r31 on output to match the Andes toolchain.
foreach i = 0-31 in {
  def R#i : NDS32Reg<"$r"#i, i>;
}

// Register Class
def GPR : RegisterClass<"NDS32", [i32], 32, (add
  R0, R1, R2, R3, R4, R5, R6, R7,
  R8, R9, R10, R11, R12, R13, R14, R15,
  R16, R17, R18, R19, R20, R21, R22, R23,
  R24, R25, R26, R27, R28, R29, R30, R31
)>;

// 4-bit register subset for the add45/addi45 16-bit forms. The hardware encodes
// only r0-r11 (codes 0-11) and r16-r19 (codes 12-15); r12-r15 and r20-r31 are
// NOT encodable. The non-linear reg->code map (r16-r19 -> 12-15) is handled by
// the custom encoder/decoder (encodeGPR4 / decodeGPR4), so this class only needs
// to restrict which registers are legal operands.
def GPR4 : RegisterClass<"NDS32", [i32], 32, (add
  R0, R1, R2, R3, R4, R5, R6, R7, R8, R9, R10, R11,
  R16, R17, R18, R19
)>;
// Operand wrapper carrying the custom 4-bit encode/decode (RegisterClass itself
// has no EncoderMethod field).
def gpr4 : RegisterOperand<GPR4> {
  let EncoderMethod = "encodeGPR4";
  let DecoderMethod = "decodeGPR4";
}

def CSR_NDS32 : CalleeSavedRegs<(add
  R6, R7, R8, R9, R10, R11, R12, R13, R14, R28, R30
)>;

// Single-precision FPU registers ($fs0-$fs31) for the V3f hard-float feature.
class NDS32FPR<string n, bits<5> num> : Register<n> {
  let Namespace = "NDS32";
  let HWEncoding{4-0} = num;
}
foreach i = 0-31 in {
  def FS#i : NDS32FPR<"$fs"#i, i>;
}
def FPR32 : RegisterClass<"NDS32", [f32], 32, (sequence "FS%u", 0, 31)>;
