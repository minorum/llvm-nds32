add_llvm_component_library(LLVMNDS32Info
  NDS32TargetInfo.cpp

  LINK_COMPONENTS
  MC
  Support

  ADD_TO_COMPONENT
  NDS32
  )
