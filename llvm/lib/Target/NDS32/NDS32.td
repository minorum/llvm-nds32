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
def FeatureFPU : SubtargetFeature<"fpu", "HasFPU", "true",
                  "Support the single-precision hardware FPU (AndeStar V3f)",
                  [FeatureV3]>;
def HasFPU : Predicate<"Subtarget->hasFPU()">;

include "NDS32RegisterInfo.td"
include "NDS32InstrInfo.td"

def NDS32InstrInfo : InstrInfo;

// LLVM 22 requires targets to map the pointer operands of the standard
// target-independent pseudo instructions to a concrete register class.
defm : RemapAllTargetPseudoPointerOperands<GPR>;

// In-order, single-issue scheduling model approximating the Andes N9 core: one
// instruction issued per cycle, two-cycle load-use latency. CompleteModel is
// off since per-instruction SchedWrites are not yet defined; the scheduler
// falls back to defaults for unannotated instructions.
def NDS32SchedModel : SchedMachineModel {
  let IssueWidth = 1;
  let MicroOpBufferSize = 0; // in-order
  let LoadLatency = 2;
  let MispredictPenalty = 5;
  let CompleteModel = 0;
}

// "generic" defaults to the V2 baseline; "v2"/"v3" select the ISA explicitly.
def : ProcessorModel<"generic", NDS32SchedModel, [FeatureV2]>;
def : ProcessorModel<"nds32",   NDS32SchedModel, [FeatureV2]>;
def : ProcessorModel<"v2",      NDS32SchedModel, [FeatureV2]>;
def : ProcessorModel<"v3",      NDS32SchedModel, [FeatureV3]>;
def : ProcessorModel<"v3f",     NDS32SchedModel, [FeatureFPU]>;

def NDS32 : Target {
  let InstructionSet = NDS32InstrInfo;
}
