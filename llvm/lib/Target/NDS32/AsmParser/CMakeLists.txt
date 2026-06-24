add_llvm_component_library(LLVMNDS32AsmParser
  NDS32AsmParser.cpp

  LINK_COMPONENTS
  MC
  MCParser
  NDS32Info
  Support

  ADD_TO_COMPONENT
  NDS32
  )
