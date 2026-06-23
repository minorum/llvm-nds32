; RUN: llc -mtriple=nds32be-unknown-none-elf -filetype=obj < %s -o %t

define i32 @object_smoke(i32 %x, ptr %p) {
entry:
  store i32 %x, ptr %p, align 4
  %v = load i32, ptr %p, align 4
  %sum = add i32 %v, 42
  ret i32 %sum
}
