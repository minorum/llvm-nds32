/* Hard-float ABI driver: compiled by Andes gcc with -mfloat-abi=hard, it calls
 * our llc-compiled hard-float functions (ours_hf.ll) across the real 2fp+ ABI
 * (f32 in $fs registers). Returns 0 only if every check passes. */
#include <stdio.h>

extern float fadd(float, float);
extern float fsub(float, float);
extern float fmul(float, float);
extern float fdiv(float, float);
extern float fmuladd(float, float, float);
extern float fsum7(float, float, float, float, float, float, float);
extern float fmix(int, float, int, float);
extern int   f2i(float);
extern float i2f(int);
extern float call_gscale(float);

/* Called back by our call_gscale (our code -> this gcc function). */
float gscale(float x) { return x * 10.0f; }

static int fails = 0;
#define FCHECK(expr, want)                                                     \
  do {                                                                         \
    float got_ = (expr);                                                       \
    if (got_ != (float)(want)) {                                               \
      printf("FAIL %-14s got=%g want=%g\n", #expr, (double)got_,               \
             (double)(want));                                                  \
      fails++;                                                                 \
    }                                                                          \
  } while (0)
#define ICHECK(expr, want)                                                     \
  do {                                                                         \
    long got_ = (long)(expr);                                                  \
    if (got_ != (long)(want)) {                                                \
      printf("FAIL %-14s got=%ld want=%ld\n", #expr, got_, (long)(want));      \
      fails++;                                                                 \
    }                                                                          \
  } while (0)

int main(void) {
  FCHECK(fadd(1.5f, 2.25f), 3.75f);
  FCHECK(fsub(5.0f, 1.25f), 3.75f);
  FCHECK(fmul(2.5f, 4.0f), 10.0f);
  FCHECK(fdiv(10.0f, 4.0f), 2.5f);
  FCHECK(fmuladd(2.0f, 3.0f, 1.5f), 7.5f);

  /* 1+2+4+8+16+32+64 = 127 (seventh arg via the stack) */
  FCHECK(fsum7(1.0f, 2.0f, 4.0f, 8.0f, 16.0f, 32.0f, 64.0f), 127.0f);

  /* (3+4) + 1.5*2.0 = 7 + 3 = 10 ; independent int/float register pools */
  FCHECK(fmix(3, 1.5f, 4, 2.0f), 10.0f);

  ICHECK(f2i(3.75f), 3);
  FCHECK(i2f(7), 7.0f);

  /* our code calls gscale(2.5)=25.0, then +1.0 = 26.0 */
  FCHECK(call_gscale(2.5f), 26.0f);

  if (fails == 0) { printf("HARD-FLOAT: ALL PASS\n"); return 0; }
  printf("%d FAILURE(S)\n", fails);
  return fails;
}
