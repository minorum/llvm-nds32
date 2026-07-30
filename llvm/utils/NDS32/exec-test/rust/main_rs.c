#include <stdint.h>
#include <stdio.h>
extern uint32_t rs_count_ones(uint32_t), rs_leading_zeros(uint32_t), rs_swap_bytes(uint32_t);
extern uint32_t rs_rotate_left(uint32_t, uint32_t), rs_gcd(uint32_t, uint32_t), rs_isqrt(uint32_t);
extern int32_t  rs_checked_add(int32_t, int32_t), rs_max(int32_t, int32_t);
extern int64_t  rs_slice_sum(const int32_t*, uint32_t);
extern int64_t  rs_mul128_hi(int64_t, int64_t);
extern uint64_t rs_udiv128(uint64_t, uint64_t, uint64_t);
extern int64_t  rs_sort_checksum(int32_t*, uint32_t);
extern int32_t  rs_bsearch(const int32_t*, uint32_t, int32_t);
extern int32_t  rs_parse_dec(void), rs_parse_hex(void), rs_sat_add(int32_t, int32_t);
extern int32_t  rs_fp_avg(int32_t, int32_t);
extern uint32_t rs_format(uint8_t*, int32_t);
extern int32_t  rs_dyn(int32_t, int32_t);
#include <string.h>

static int fails = 0;
#define CHECK(e, w) do{ long long g=(long long)(e), x=(long long)(w); \
  if(g!=x){ printf("FAIL %-16s got=%lld want=%lld\n", #e, g, x); fails++; } }while(0)

int main(void){
  CHECK(rs_count_ones(0xF0F0F0F0u), 16);
  CHECK(rs_leading_zeros(0x00010000u), 15);
  CHECK(rs_swap_bytes(0x11223344u), 0x44332211);
  CHECK(rs_rotate_left(0x12345678u, 8), 0x34567812);
  CHECK(rs_checked_add(20, 22), 42);
  CHECK(rs_checked_add(2000000000, 2000000000), -1);
  CHECK(rs_max(7, 3), 7);
  CHECK(rs_gcd(48, 36), 12);
  int32_t arr[5] = {10,20,30,40,50};
  CHECK(rs_slice_sum(arr, 5), 150);
  CHECK(rs_isqrt(144), 12);
  CHECK(rs_isqrt(143), 11);

  /* i128 */
  CHECK(rs_mul128_hi(0x100000000LL, 0x100000000LL), 1);     /* 2^64 >> 64 */
  CHECK(rs_udiv128(1, 0, 4), 0x4000000000000000ULL);        /* 2^64 / 4 */

  /* sorting: sort {5,3,1,4,2} -> {1,2,3,4,5}; checksum sum((i+1)*v) */
  { int32_t a[5] = {5,3,1,4,2};
    CHECK(rs_sort_checksum(a, 5), 1*1+2*2+3*3+4*4+5*5); }   /* = 55 */

  /* binary search in sorted {2,4,6,8,10} */
  { int32_t s[5] = {2,4,6,8,10};
    CHECK(rs_bsearch(s, 5, 8), 3);
    CHECK(rs_bsearch(s, 5, 5), -1); }

  /* parsing */
  CHECK(rs_parse_dec(), 12345);
  CHECK(rs_parse_hex(), 255);

  /* float */
  CHECK(rs_fp_avg(10, 20), 15);

  /* saturating */
  CHECK(rs_sat_add(2000000000, 2000000000), 2147483647);

  /* core::fmt: runtime integer Display (regression for the j/jal fixup bug) */
  { uint8_t b[32]; uint32_t n = rs_format(b, 255); b[n] = 0;
    if (strcmp((char*)b, "v=255 x=ff") != 0) {
      printf("FAIL rs_format        got=\"%s\" want=\"v=255 x=ff\"\n", b); fails++; } }

  /* trait-object dynamic dispatch */
  CHECK(rs_dyn(0, 5), 15);   /* Add(10): 5+10 */
  CHECK(rs_dyn(1, 5), 20);   /* Mul(4):  5*4  */

  if(fails==0){ printf("RUST CORE: ALL PASS\n"); return 0; }
  printf("%d FAILURE(S)\n", fails); return fails;
}
