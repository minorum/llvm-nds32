# RUN: not llvm-mc -triple=nds32be-unknown-none-elf %s 2>&1 | FileCheck %s

standby -1
# CHECK: :[[@LINE-1]]:9: error: invalid operand for instruction
standby 4
# CHECK: :[[@LINE-1]]:9: error: invalid operand for instruction
break16 -1
# CHECK: :[[@LINE-1]]:9: error: invalid operand for instruction
break16 32
# CHECK: :[[@LINE-1]]:9: error: invalid operand for instruction
