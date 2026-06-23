add_llvm_component_library(LLVMNDS32Desc
  NDS32AsmBackend.cpp
  NDS32ELFObjectWriter.cpp
  NDS32MCTargetDesc.cpp
  NDS32MCAsmInfo.cpp
  NDS32MCCodeEmitter.cpp
  NDS32InstPrinter.cpp

  LINK_COMPONENTS
  BinaryFormat
  MC
  NDS32Info
  Support

  ADD_TO_COMPONENT
  NDS32
  )
