include "llvm/Target/Target.td"

//===----------------------------------------------------------------------===//
// NDS32 ISA versions (AndeStar). The base ISA versions are V1, V2 and V3; V3
// additionally has the V3m (reduced register set), V3f (single-precision FPU)
// and V3s (V3 + DSP) sub-variants. We currently model the V2 and V3 base
// instruction sets, with V3 a strict superset of V2.
//===----------------------------------------------------------------------===//

def FeatureV2 : SubtargetFeature<"v2", "HasV2Ops", "true",
                  "Support the NDS32 baseline (AndeStar V2) instruction set">;
def FeatureV3 : SubtargetFeature<"v3", "HasV3Ops", "true",
                  "Support the NDS32 AndeStar V3 instruction set",
                  [FeatureV2]>;

include "NDS32RegisterInfo.td"
include "NDS32InstrInfo.td"

def NDS32InstrInfo : InstrInfo;

// LLVM 22 requires targets to map the pointer operands of the standard
// target-independent pseudo instructions to a concrete register class.
defm : RemapAllTargetPseudoPointerOperands<GPR>;

// "generic" defaults to the V2 baseline; "v2"/"v3" select the ISA explicitly.
def : Processor<"generic", NoItineraries, [FeatureV2]>;
def : Processor<"nds32",   NoItineraries, [FeatureV2]>;
def : Processor<"v2",      NoItineraries, [FeatureV2]>;
def : Processor<"v3",      NoItineraries, [FeatureV3]>;

def NDS32 : Target {
  let InstructionSet = NDS32InstrInfo;
}
