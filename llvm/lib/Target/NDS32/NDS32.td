//===-- NDS32.td - Describe the NDS32 target machine -------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

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
def HasV3Ops : Predicate<"Subtarget->hasV3Ops()">;
def FeatureFPU : SubtargetFeature<"fpu", "HasFPU", "true",
                  "Support the single-precision hardware FPU (AndeStar V3f)",
                  [FeatureV3]>;
def HasFPU : Predicate<"Subtarget->hasFPU()">;
// Hard-float ABI (Andes 2fp+): single-precision floats are passed/returned in
// FP registers instead of GPRs. Opt-in on top of the FPU ISA, mirroring GCC's
// split of -mext-fpu-sp (ISA) from -mfloat-abi=hard (ABI). Enable with
// `-mattr=+hard-float-abi` or the `v3f-hard` processor.
def FeatureHardFloatABI : SubtargetFeature<"hard-float-abi", "HasHardFloatABI",
                  "true", "Pass single-precision floats in FP registers "
                  "(Andes 2fp+ hard-float ABI)", [FeatureFPU]>;

//===----------------------------------------------------------------------===//
// Core-configuration features (orthogonal to the ISA version). Both describe
// how a *specific* core is built rather than which ISA it implements, so they
// are plain opt-ins with no implied ISA level.
//
// The MT6785 conn-MCU needs both — see nds32be-conn-mcu.json, and
// mt6785-connsys-firmware/docs/07-environment-setup.md for why their absence
// silently produced faulting code.
//===----------------------------------------------------------------------===//

// Andes "reduced register" core configuration (as GCC's -mreduced-regs): only
// r0-r10, r15 and r28-r31 exist. Allocating r11-r14 or r16-r27 produces code
// that faults on such a core.
def FeatureReducedRegs : SubtargetFeature<"reduced-regs", "HasReducedRegs",
                  "true", "Only the Andes reduced register set is implemented "
                  "(r0-r10, r15, r28-r31)">;

// The Andes 16-bit instruction extension, which Andes' own tools model as an
// extension a part either implements or does not: GCC spells it -m16-bit /
// -mno-16-bit and the assembler -m[no-]16bit-ext. So this is a positive
// feature naming a capability, matching the assembler's spelling — presence
// means the compressed forms may be emitted.
//
// It was previously a negative feature ("no-16bit") whose absence asserted the
// extension was present. That inverts the convention every other feature here
// follows, and it defaulted the more aggressive choice on: a subtarget that
// simply forgot the flag emitted compressed forms silently. Every NDS32
// baseline this backend targets does implement the extension, so the processor
// models below carry it and nothing changes for a build that names a CPU; a
// core configured without it subtracts it (-16bit-ext) and says so explicitly.
def Feature16BitExt : SubtargetFeature<"16bit-ext", "Has16BitExt", "true",
                  "Andes 16-bit (compressed) instruction extension">;

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
// Every one carries Feature16BitExt: the 16-bit extension is implemented on the
// NDS32 baselines this backend targets (the MT6785 conn-MCU's own vendor
// firmware is 45.7% 16-bit encodings). A part without it, or a build that
// deliberately declines to use it, subtracts it with -mattr=-16bit-ext.
def : ProcessorModel<"generic", NDS32SchedModel, [FeatureV2, Feature16BitExt]>;
def : ProcessorModel<"nds32",   NDS32SchedModel, [FeatureV2, Feature16BitExt]>;
def : ProcessorModel<"v2",      NDS32SchedModel, [FeatureV2, Feature16BitExt]>;
def : ProcessorModel<"v3",      NDS32SchedModel, [FeatureV3, Feature16BitExt]>;
def : ProcessorModel<"v3f",     NDS32SchedModel, [FeatureFPU, Feature16BitExt]>;
def : ProcessorModel<"v3f-hard", NDS32SchedModel,
                     [FeatureHardFloatABI, Feature16BitExt]>;

def NDS32 : Target {
  let InstructionSet = NDS32InstrInfo;
}
