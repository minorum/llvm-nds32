class NDS32Reg<string n, bits<5> num> : Register<n> {
  let Namespace = "NDS32";
  let HWEncoding{4-0} = num;
}

// General Purpose Registers
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

def CSR_NDS32 : CalleeSavedRegs<(add
  R6, R7, R8, R9, R10, R11, R12, R13, R14, R28, R30
)>;
