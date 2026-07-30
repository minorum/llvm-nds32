# LLVM with an Andes NDS32 backend

This is a fork of [llvm/llvm-project](https://github.com/llvm/llvm-project) at
`llvmorg-22.1.0` adding a **code generator for the Andes NDS32 (AndeStar)
architecture**, big-endian included. Upstream LLVM has no NDS32 target; this one
exists to compile Rust `no_std` firmware for an NDS32 coprocessor.

- **The backend lives in [`llvm/lib/Target/NDS32/`](llvm/lib/Target/NDS32).**
- **`nds32-v22.1.0` is the branch that has it**, and is the default branch.
  `main` is untouched upstream LLVM and contains **no** NDS32 target at all.
- LLVM 22 was chosen to match rustc-nightly's bundled LLVM, so rustc's IR parses
  and lowers directly.

## Developed with AI assistance

This backend is written largely with AI assistance (Anthropic's Claude), under
human direction and review. That is stated plainly because it should inform how
you read the code: treat it as you would any unfamiliar contributor's work, and
lean on the checks rather than on authorship.

The project's answer to "how do you trust it?" is that nothing here is accepted
on the basis of looking plausible:

- Instruction encodings are **differentially tested against the Andes
  `nds32be-elf` binutils**, byte for byte, not hand-derived. The system-register
  table is generated from binutils rather than transcribed (273 spellings, both
  mnemonics, plus a disassembly round-trip).
- Compiled code is **executed on the Andes nds32 ISS**, which has caught silent
  miscompiles that exact-output FileCheck structurally cannot.
- Behaviour changes land with a focused CodeGen or MC test.

Where a claim in this README is not backed by one of those, it is a claim about
intent, not evidence.

## What's implemented

Full ABI, frame pointer + alloca, varargs, register-offset and post-increment
addressing, PIC/TLS, single-precision hard-float, 16-bit compression, system
registers, and the complete MC layer (TableGen-driven encoder, disassembler,
AsmParser). Rust `core` and `compiler_builtins` compile to valid NDS32 objects
and execute correctly on the Andes nds32 ISS.

Processors: `v2` (= `generic`), `v3`, `v3f`, `v3f-hard`. Primary triple:
`nds32be-unknown-none-elf`.

### Core-configuration features

Beyond the ISA level, two subtarget features describe how a particular core was
*built*. Both matter on real silicon, and both used to fail silently:

| Feature | Meaning |
|---|---|
| `+reduced-regs` | Only the Andes reduced register set exists (r0–r10, r15, r28–r31). Allocating r11–r14 or r16–r27 yields code that **faults** on such a core. |
| `+no-16bit` | Never emit 16-bit (compressed) forms. |

Relatedly, `bitci` is V3-baseline only — a V2 core traps on it — so the
`(and reg, imm)` → `bitci` pattern is gated behind `HasV3Ops`, and V2 lowers the
same expression to `movi`+`and`.

## Building

```sh
cmake -S llvm -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_TARGETS_TO_BUILD=X86 \
  -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=NDS32 \
  -DLLVM_ENABLE_ASSERTIONS=ON
ninja -C build llc llvm-mc llvm-objdump
```

NDS32 is an *experimental* target, so `LLVM_EXPERIMENTAL_TARGETS_TO_BUILD` is
required. Keep your host (`X86` above) in `LLVM_TARGETS_TO_BUILD` if you intend
to link a host rustc against this build.

## Testing

The build above sets no `LLVM_INCLUDE_TESTS`, and the downstream configuration
disables it, so `llvm-lit` may not discover the suite. The companion repo
[minorum/nds32-llvm](https://github.com/minorum/nds32-llvm) carries a small lit
replacement plus the execution suites:

```sh
bash scripts/run-nds32-tests.sh    # CodeGen + MC, exact-output FileCheck; invariant FAIL=0
python3 scripts/verify-sysregs.py  # every sysreg spelling byte-compared against binutils
bash scripts/run-exec-test.sh      # compiled code actually RUN on the Andes nds32 ISS
```

Do not settle for "the tests compile". Running code on the ISS has caught silent
miscompiles — data endianness, PIC jump tables, a 1-bit branch-fixup mask — that
FileCheck-on-assembly structurally cannot.

`llvm/lib/Target/NDS32/NDS32SysRegs.td` is **generated**: the system-register
names come from binutils' `keyword_sr` and each SRIDX is read back out of real
`nds32be-elf-as` output rather than reimplementing binutils' encoding macro.
Regenerate it with `scripts/gen-sysregs.py`; do not hand-edit.

## Related repositories

- [minorum/nds32-llvm](https://github.com/minorum/nds32-llvm) — wrapper: Rust
  target specs (including `nds32be-conn-mcu.json`), the build and verification
  scripts, and this fork as a submodule.
- [minorum/mt6785-connsys-firmware](https://github.com/minorum/mt6785-connsys-firmware)
  — the consumer: a Rust reconstruction of the MediaTek MT6785 connectivity-
  coprocessor firmware. Its `docs/07-environment-setup.md` documents the whole
  toolchain and how to rebuild it from nothing.

Upstream LLVM's README follows.

---

# The LLVM Compiler Infrastructure

[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/llvm/llvm-project/badge)](https://securityscorecards.dev/viewer/?uri=github.com/llvm/llvm-project)
[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/8273/badge)](https://www.bestpractices.dev/projects/8273)
[![libc++](https://github.com/llvm/llvm-project/actions/workflows/libcxx-build-and-test.yaml/badge.svg?branch=main&event=schedule)](https://github.com/llvm/llvm-project/actions/workflows/libcxx-build-and-test.yaml?query=event%3Aschedule)

Welcome to the LLVM project!

This repository contains the source code for LLVM, a toolkit for the
construction of highly optimized compilers, optimizers, and run-time
environments.

The LLVM project has multiple components. The core of the project is
itself called "LLVM". This contains all of the tools, libraries, and header
files needed to process intermediate representations and convert them into
object files. Tools include an assembler, disassembler, bitcode analyzer, and
bitcode optimizer.

C-like languages use the [Clang](https://clang.llvm.org/) frontend. This
component compiles C, C++, Objective-C, and Objective-C++ code into LLVM bitcode
-- and from there into object files, using LLVM.

Other components include:
the [libc++ C++ standard library](https://libcxx.llvm.org),
the [LLD linker](https://lld.llvm.org), and more.

## Getting the Source Code and Building LLVM

Consult the
[Getting Started with LLVM](https://llvm.org/docs/GettingStarted.html#getting-the-source-code-and-building-llvm)
page for information on building and running LLVM.

For information on how to contribute to the LLVM project, please take a look at
the [Contributing to LLVM](https://llvm.org/docs/Contributing.html) guide.

## Getting in touch

Join the [LLVM Discourse forums](https://discourse.llvm.org/), [Discord
chat](https://discord.gg/xS7Z362),
[LLVM Office Hours](https://llvm.org/docs/GettingInvolved.html#office-hours) or
[Regular sync-ups](https://llvm.org/docs/GettingInvolved.html#online-sync-ups).

The LLVM project has adopted a [code of conduct](https://llvm.org/docs/CodeOfConduct.html) for
participants to all modes of communication within the project.
