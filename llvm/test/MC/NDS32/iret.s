# RUN: llvm-mc -triple=nds32be-unknown-none-elf -show-encoding %s | FileCheck %s
#
# iret: exception return (op6=0x32, sub=0x04). Restores $psw from $ipsw and
# jumps to $ipc atomically -- the terminator of a context switch, which a `ret`
# cannot express. Encoding checked against the MT6785 mask ROM, where the task
# switch at 0x390 ends in these exact bytes.

# CHECK: iret
# CHECK-SAME: encoding: [0x64,0x00,0x00,0x04]
iret
