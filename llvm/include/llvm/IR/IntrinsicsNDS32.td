//===- IntrinsicsNDS32.td - NDS32 intrinsics ----------------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

let TargetPrefix = "nds32" in {

// DSB orders observable memory accesses, so it intentionally has conservative
// memory effects. ISB serialises the instruction stream but not IR memory.
def int_nds32_dsb : Intrinsic<[], [],
    [IntrHasSideEffects, IntrWillReturn, IntrNoFree]>;
def int_nds32_isb : Intrinsic<[], [],
    [IntrNoMem, IntrHasSideEffects, IntrWillReturn, IntrNoFree]>;

// Direct processor-state operations. Their arguments are immediate encoding
// fields rather than generic IR memory-order or power-state abstractions.
def int_nds32_setgie_d : Intrinsic<[], [],
    [IntrNoMem, IntrHasSideEffects, IntrWillReturn, IntrNoFree]>;
def int_nds32_setgie_e : Intrinsic<[], [],
    [IntrNoMem, IntrHasSideEffects, IntrWillReturn, IntrNoFree]>;
def int_nds32_standby : Intrinsic<[], [llvm_i32_ty],
    [IntrNoMem, IntrHasSideEffects, IntrConvergent, IntrNoDuplicate,
     IntrWillReturn, IntrNoFree, ImmArg<ArgIndex<0>>]>;

// A debugger exception can resume at the following instruction, unlike
// llvm.trap. Keep that exact behavior in a target intrinsic.
def int_nds32_break16 : Intrinsic<[], [llvm_i32_ty],
    [IntrNoMem, IntrHasSideEffects, IntrCold, IntrNoFree,
     ImmArg<ArgIndex<0>>]>;

} // TargetPrefix = "nds32"
