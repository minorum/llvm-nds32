add_llvm_component_library(LLVMNDS32Disassembler
  NDS32Disassembler.cpp

  LINK_COMPONENTS
  MCDisassembler
  NDS32Info
  Support

  ADD_TO_COMPONENT
  NDS32
  )
