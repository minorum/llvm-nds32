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

// Suppress the 16-bit (compressed) instruction forms.
def FeatureNo16Bit : SubtargetFeature<"no-16bit", "HasNo16Bit", "true",
                  "Do not emit 16-bit (compressed) instruction forms">;

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
def : ProcessorModel<"v3f-hard", NDS32SchedModel, [FeatureHardFloatABI]>;

def NDS32 : Target {
  let InstructionSet = NDS32InstrInfo;
}
