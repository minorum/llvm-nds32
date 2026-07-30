; Functions compiled by OUR llc backend, exercised at runtime on the nds32 sim.
target datalayout = "E-m:e-p:32:32-i64:32-f64:32-a:0:32-n32-S32"

@g   = global i32 100, align 4
@arr = global [8 x i32] [i32 10, i32 20, i32 30, i32 40, i32 50, i32 60, i32 70, i32 80], align 4
@pg  = global ptr @g, align 4   ; pointer-to-global: data relocation (R_NDS32_32 / GOT)

;; ---- basics / ABI ----
define i32 @add(i32 %a, i32 %b) { %s = add i32 %a, %b ret i32 %s }
define i32 @load_g() { %v = load i32, ptr @g ret i32 %v }

define i32 @sum_to(i32 %n) {
entry: br label %loop
loop:
  %i   = phi i32 [ 0, %entry ], [ %ni, %loop ]
  %acc = phi i32 [ 0, %entry ], [ %na, %loop ]
  %na  = add i32 %acc, %i
  %ni  = add i32 %i, 1
  %c   = icmp slt i32 %ni, %n
  br i1 %c, label %loop, label %done
done: ret i32 %na
}

define i64 @add64(i64 %a, i64 %b) { %s = add i64 %a, %b ret i64 %s }

;; ---- division / remainder (libcalls) ----
define i32 @sdiv_(i32 %a, i32 %b) { %d = sdiv i32 %a, %b ret i32 %d }
define i32 @udiv_(i32 %a, i32 %b) { %d = udiv i32 %a, %b ret i32 %d }
define i32 @srem_(i32 %a, i32 %b) { %r = srem i32 %a, %b ret i32 %r }

;; ---- i64 multiply / shifts ----
define i64 @mul64(i64 %a, i64 %b) { %m = mul i64 %a, %b ret i64 %m }
define i64 @shl64(i64 %a, i64 %n) { %s = shl i64 %a, %n ret i64 %s }
define i64 @ashr64(i64 %a, i64 %n) { %s = ashr i64 %a, %n ret i64 %s }

;; ---- narrow memory with sign/zero extension ----
define i32 @load_sb(ptr %p) { %v = load i8,  ptr %p  %s = sext i8  %v to i32 ret i32 %s }
define i32 @load_ub(ptr %p) { %v = load i8,  ptr %p  %z = zext i8  %v to i32 ret i32 %z }
define i32 @load_sh(ptr %p) { %v = load i16, ptr %p  %s = sext i16 %v to i32 ret i32 %s }
define void @store_h(ptr %p, i32 %x) { %t = trunc i32 %x to i16 store i16 %t, ptr %p ret void }

;; ---- global array index (reg-offset addressing) ----
define i32 @arr_get(i32 %i) {
  %p = getelementptr [8 x i32], ptr @arr, i32 0, i32 %i
  %v = load i32, ptr %p
  ret i32 %v
}

;; ---- jump-table switch ----
define i32 @sw(i32 %x) {
entry:
  switch i32 %x, label %def [ i32 0, label %c0  i32 1, label %c1  i32 2, label %c2  i32 3, label %c3 ]
c0: ret i32 100
c1: ret i32 200
c2: ret i32 300
c3: ret i32 400
def: ret i32 -1
}

;; ---- recursion ----
define i32 @fact(i32 %n) {
entry:
  %c = icmp sle i32 %n, 1
  br i1 %c, label %base, label %rec
base: ret i32 1
rec:
  %n1 = sub i32 %n, 1
  %r  = call i32 @fact(i32 %n1)
  %m  = mul i32 %n, %r
  ret i32 %m
}

;; ---- many args (stack arguments beyond $r0-$r5) ----
define i32 @many(i32 %a, i32 %b, i32 %c, i32 %d, i32 %e, i32 %f, i32 %g, i32 %h) {
  %1 = add i32 %a, %b
  %2 = add i32 %1, %c
  %3 = add i32 %2, %d
  %4 = add i32 %3, %e
  %5 = add i32 %4, %f
  %6 = add i32 %5, %g
  %7 = add i32 %6, %h
  ret i32 %7
}

;; ---- select / efficiency / immediates ----
define i32 @smin(i32 %a, i32 %b) { %c = icmp slt i32 %a, %b  %m = select i1 %c, i32 %a, i32 %b  ret i32 %m }

declare i32 @llvm.bswap.i32(i32)
define i32 @bswap_(i32 %x) { %r = call i32 @llvm.bswap.i32(i32 %x) ret i32 %r }

declare i32 @llvm.ctlz.i32(i32, i1)
define i32 @clz_(i32 %x) { %r = call i32 @llvm.ctlz.i32(i32 %x, i1 false) ret i32 %r }

define i32 @bigimm() { ret i32 305419896 }   ; 0x12345678
define i32 @negimm() { ret i32 -12345 }

;; ---- soft-float f32 / f64 (libcalls + FP ABI) ----
define float  @fadd32(float %a, float %b)   { %r = fadd float %a, %b    ret float %r }
define float  @fmul32(float %a, float %b)   { %r = fmul float %a, %b    ret float %r }
define double @fadd64(double %a, double %b) { %r = fadd double %a, %b   ret double %r }
define double @fmul64(double %a, double %b) { %r = fmul double %a, %b   ret double %r }
define i32    @f2i(float %a)                { %r = fptosi float %a to i32  ret i32 %r }
define float  @i2f(i32 %a)                  { %r = sitofp i32 %a to float  ret float %r }
define float  @d2f(double %a)               { %r = fptrunc double %a to float  ret float %r }
define double @f2d(float %a)                { %r = fpext float %a to double    ret double %r }
define i32    @flt(float %a, float %b)      { %c = fcmp olt float %a, %b  %z = zext i1 %c to i32  ret i32 %z }

;; ---- varargs (register save area + va_arg) ----
declare void @llvm.va_start(ptr)
declare void @llvm.va_end(ptr)
define i32 @vsum(i32 %n, ...) {
entry:
  %ap = alloca ptr, align 4
  call void @llvm.va_start(ptr %ap)
  br label %loop
loop:
  %i   = phi i32 [ 0, %entry ], [ %ni, %body ]
  %acc = phi i32 [ 0, %entry ], [ %na, %body ]
  %c   = icmp slt i32 %i, %n
  br i1 %c, label %body, label %end
body:
  %v  = va_arg ptr %ap, i32
  %na = add i32 %acc, %v
  %ni = add i32 %i, 1
  br label %loop
end:
  call void @llvm.va_end(ptr %ap)
  ret i32 %acc
}

;; ---- small struct by value (<=8B in $r0:$r1) ----
%pair = type { i32, i32 }
define i32 @sum_pair(%pair %p) {
  %a = extractvalue %pair %p, 0
  %b = extractvalue %pair %p, 1
  %s = add i32 %a, %b
  ret i32 %s
}

;; ---- small struct returned (<=8B in $r0:$r1) ----
define %pair @mk_pair(i32 %x) {
  %r0 = insertvalue %pair undef, i32 %x, 0
  %x1 = add i32 %x, 1
  %r1 = insertvalue %pair %r0, i32 %x1, 1
  ret %pair %r1
}

;; ---- 12B struct by value (split across $r0:$r1:$r2) ----
%trip = type { i32, i32, i32 }
define i32 @sum_trip(%trip %p) {
  %a  = extractvalue %trip %p, 0
  %b  = extractvalue %trip %p, 1
  %c  = extractvalue %trip %p, 2
  %s1 = add i32 %a, %b
  %s2 = add i32 %s1, %c
  ret i32 %s2
}

;; ---- struct straddling registers and the stack ($r4,$r5 + 1 stack word) ----
define i32 @straddle(i32 %a, i32 %b, i32 %c, i32 %d, %trip %p) {
  %x  = extractvalue %trip %p, 0
  %y  = extractvalue %trip %p, 1
  %z  = extractvalue %trip %p, 2
  %s1 = add i32 %a, %b
  %s2 = add i32 %s1, %c
  %s3 = add i32 %s2, %d
  %s4 = add i32 %s3, %x
  %s5 = add i32 %s4, %y
  %s6 = add i32 %s5, %z
  ret i32 %s6
}

;; ---- pointer stored in data, dereferenced (data relocation / GOT) ----
define i32 @load_via_pg() {
  %p = load ptr, ptr @pg
  %v = load i32, ptr %p
  ret i32 %v
}

;; ---- indirect call through a function pointer (jral) ----
define i32 @dbl(i32 %x) { %r = shl i32 %x, 1 ret i32 %r }
define i32 @apply(ptr %fn, i32 %x) {
  %r = call i32 %fn(i32 %x)
  ret i32 %r
}

;; ---- vararg doubles (8-byte even-pair save area + va_arg alignment) ----
define double @dsum(i32 %n, ...) {
entry:
  %ap = alloca ptr, align 4
  call void @llvm.va_start(ptr %ap)
  br label %loop
loop:
  %i   = phi i32    [ 0,   %entry ], [ %ni, %body ]
  %acc = phi double [ 0.0, %entry ], [ %na, %body ]
  %c   = icmp slt i32 %i, %n
  br i1 %c, label %body, label %end
body:
  %v  = va_arg ptr %ap, double
  %na = fadd double %acc, %v
  %ni = add i32 %i, 1
  br label %loop
end:
  call void @llvm.va_end(ptr %ap)
  ret double %acc
}

;; ---- sret: large struct returned via hidden pointer in $r0 ----
%Big = type { i32, i32, i32, i32 }
define void @make_big(ptr sret(%Big) %out, i32 %seed) {
  %p0 = getelementptr %Big, ptr %out, i32 0, i32 0
  store i32 %seed, ptr %p0
  %s1 = add i32 %seed, 1
  %p1 = getelementptr %Big, ptr %out, i32 0, i32 1
  store i32 %s1, ptr %p1
  %s2 = add i32 %seed, 2
  %p2 = getelementptr %Big, ptr %out, i32 0, i32 2
  store i32 %s2, ptr %p2
  %s3 = add i32 %seed, 3
  %p3 = getelementptr %Big, ptr %out, i32 0, i32 3
  store i32 %s3, ptr %p3
  ret void
}
