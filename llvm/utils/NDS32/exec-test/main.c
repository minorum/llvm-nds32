#include <stdint.h>
#include <stdio.h>

/* Functions under test, compiled by our llc backend (ours.ll). */
extern int add(int, int);
extern int load_g(void);
extern int sum_to(int);
extern int64_t add64(int64_t, int64_t);
extern int sdiv_(int, int), udiv_(unsigned, unsigned), srem_(int, int);
extern int64_t mul64(int64_t, int64_t), shl64(int64_t, int64_t), ashr64(int64_t, int64_t);
extern int load_sb(void *), load_ub(void *), load_sh(void *);
extern void store_h(void *, int);
extern int arr_get(int), sw(int), fact(int), smin(int, int);
extern int many(int, int, int, int, int, int, int, int);
extern int bswap_(int), clz_(int), bigimm(void), negimm(void);
extern float fadd32(float, float), fmul32(float, float), i2f(int), d2f(double);
extern double fadd64(double, double), fmul64(double, double), f2d(float);
extern int f2i(float), flt(float, float);
extern int vsum(int n, ...);
typedef struct { int a, b, c, d; } Big;
extern Big make_big(int seed);
typedef struct { int a, b; } Pair;
typedef struct { int a, b, c; } Trip;
extern int sum_pair(Pair);
extern Pair mk_pair(int);
extern int sum_trip(Trip);
extern int straddle(int, int, int, int, Trip);
extern int load_via_pg(void);
extern int dbl(int);
extern int apply(int (*fn)(int), int x);
extern double dsum(int n, ...);

static int fails = 0;
#define FCHECK(expr, want)                                                     \
  do {                                                                         \
    double got_ = (double)(expr);                                             \
    if (got_ != (double)(want)) {                                              \
      printf("FAIL %-12s got=%g want=%g\n", #expr, got_, (double)(want));      \
      fails++;                                                                 \
    }                                                                          \
  } while (0)
#define CHECK(expr, want)                                                      \
  do {                                                                         \
    long long got_ = (long long)(expr);                                        \
    long long want_ = (long long)(want);                                       \
    if (got_ != want_) {                                                       \
      printf("FAIL %-12s got=%lld want=%lld\n", #expr, got_, want_);           \
      fails++;                                                                 \
    }                                                                          \
  } while (0)

int main(void) {
  /* basics / ABI */
  CHECK(add(20, 22), 42);
  CHECK(load_g(), 100);
  CHECK(sum_to(10), 45);
  CHECK(add64(0x100000000LL, 1), 0x100000001LL);

  /* division / remainder */
  CHECK(sdiv_(-100, 7), -14);
  CHECK(udiv_(100u, 7u), 14);
  CHECK(srem_(-100, 7), -2);

  /* i64 multiply / shifts */
  CHECK(mul64(1000000LL, 1000000LL), 1000000000000LL);
  CHECK(shl64(1LL, 40), 0x10000000000LL);
  CHECK(ashr64((int64_t)0xFF00000000000000ULL, 8), (int64_t)0xFFFF000000000000ULL);

  /* narrow memory + extension */
  {
    int8_t b = -5; uint8_t ub = 200; int16_t h = -1000; int16_t out = 0;
    CHECK(load_sb(&b), -5);
    CHECK(load_ub(&ub), 200);
    CHECK(load_sh(&h), -1000);
    store_h(&out, 0x12345);          /* truncates to 0x2345 */
    CHECK(out, 0x2345);
  }

  /* global array (reg-offset addressing) */
  CHECK(arr_get(0), 10);
  CHECK(arr_get(5), 60);

  /* jump-table switch */
  CHECK(sw(0), 100);
  CHECK(sw(2), 300);
  CHECK(sw(9), -1);

  /* recursion */
  CHECK(fact(5), 120);

  /* stack arguments */
  CHECK(many(1, 2, 3, 4, 5, 6, 7, 8), 36);

  /* select / efficiency / immediates */
  CHECK(smin(7, 3), 3);
  CHECK(smin(-9, 4), -9);
  CHECK(bswap_(0x11223344), 0x44332211);
  CHECK(clz_(0x00010000), 15);
  CHECK(bigimm(), 305419896);
  CHECK(negimm(), -12345);

  /* soft-float (all values exactly representable) */
  FCHECK(fadd32(1.5f, 2.25f), 3.75f);
  FCHECK(fmul32(2.5f, 4.0f), 10.0f);
  FCHECK(fadd64(1.5, 2.25), 3.75);
  FCHECK(fmul64(1.25, 8.0), 10.0);
  CHECK(f2i(3.75f), 3);
  FCHECK(i2f(7), 7.0f);
  FCHECK(d2f(3.5), 3.5f);
  FCHECK(f2d(2.25f), 2.25);
  CHECK(flt(1.0f, 2.0f), 1);
  CHECK(flt(2.0f, 1.0f), 0);

  /* varargs */
  CHECK(vsum(3, 10, 20, 30), 60);
  CHECK(vsum(5, 1, 2, 3, 4, 5), 15);

  /* sret large struct return */
  {
    Big b = make_big(5);
    CHECK(b.a, 5); CHECK(b.b, 6); CHECK(b.c, 7); CHECK(b.d, 8);
  }

  /* small struct by value / return (<=8B in $r0:$r1) */
  {
    Pair p = { 20, 22 };
    CHECK(sum_pair(p), 42);
    Pair q = mk_pair(5);
    CHECK(q.a, 5); CHECK(q.b, 6);
  }

  /* 12B struct by value, and a struct straddling regs + stack */
  {
    Trip t = { 1, 2, 3 };
    CHECK(sum_trip(t), 6);
    Trip u = { 5, 6, 7 };
    CHECK(straddle(1, 2, 3, 4, u), 28);   /* 1+2+3+4 + 5+6+7 */
  }

  /* pointer stored in data, dereferenced (data relocation / GOT) */
  CHECK(load_via_pg(), 100);

  /* indirect call through a function pointer */
  CHECK(apply(dbl, 21), 42);

  /* vararg doubles (8-byte even-pair save area) */
  FCHECK(dsum(3, 1.5, 2.25, 0.25), 4.0);

  if (fails == 0) { printf("ALL PASS\n"); return 0; }
  printf("%d FAILURE(S)\n", fails);
  return fails;
}
