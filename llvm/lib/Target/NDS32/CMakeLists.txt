add_llvm_component_group(NDS32)

set(LLVM_TARGET_DEFINITIONS NDS32.td)

tablegen(LLVM NDS32GenRegisterInfo.inc -gen-register-info)
tablegen(LLVM NDS32GenInstrInfo.inc -gen-instr-info)
tablegen(LLVM NDS32GenSubtargetInfo.inc -gen-subtarget)
tablegen(LLVM NDS32GenDAGISel.inc -gen-dag-isel)
tablegen(LLVM NDS32GenAsmWriter.inc -gen-asm-writer)

add_public_tablegen_target(NDS32CommonTableGen)

add_llvm_target(NDS32CodeGen
  NDS32TargetMachine.cpp
  NDS32ISelDAGToDAG.cpp
  NDS32ISelLowering.cpp
  NDS32Subtarget.cpp
  NDS32FrameLowering.cpp
  NDS32InstrInfo.cpp
  NDS32RegisterInfo.cpp
  NDS32AsmPrinter.cpp

  LINK_COMPONENTS
  AsmPrinter
  CodeGen
  Core
  MC
  NDS32Info
  Support
  Target
  )

add_subdirectory(MCTargetDesc)
add_subdirectory(TargetInfo)
