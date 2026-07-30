#![no_std]
use core::panic::PanicInfo;
#[panic_handler] fn panic(_: &PanicInfo) -> ! { loop {} }

// Each function exercises real core-library code, with a C ABI boundary.
#[no_mangle] pub extern "C" fn rs_count_ones(x: u32) -> u32 { x.count_ones() }
#[no_mangle] pub extern "C" fn rs_leading_zeros(x: u32) -> u32 { x.leading_zeros() }
#[no_mangle] pub extern "C" fn rs_swap_bytes(x: u32) -> u32 { x.swap_bytes() }
#[no_mangle] pub extern "C" fn rs_rotate_left(x: u32, n: u32) -> u32 { x.rotate_left(n) }
#[no_mangle] pub extern "C" fn rs_checked_add(a: i32, b: i32) -> i32 {
    match a.checked_add(b) { Some(v) => v, None => -1 }
}
#[no_mangle] pub extern "C" fn rs_max(a: i32, b: i32) -> i32 { core::cmp::max(a, b) }
#[no_mangle] pub extern "C" fn rs_gcd(mut a: u32, mut b: u32) -> u32 {
    while b != 0 { let t = b; b = a % b; a = t; }
    a
}
#[no_mangle] pub extern "C" fn rs_slice_sum(p: *const i32, n: usize) -> i64 {
    let s = unsafe { core::slice::from_raw_parts(p, n) };
    s.iter().map(|&x| x as i64).sum()
}
#[no_mangle] pub extern "C" fn rs_isqrt(x: u32) -> u32 { (x as u64).isqrt() as u32 }

// ---- harder: i128, sorting, binary search, parsing, float, saturating ----

#[no_mangle] pub extern "C" fn rs_mul128_hi(a: i64, b: i64) -> i64 {
    (((a as i128) * (b as i128)) >> 64) as i64        // __multi3
}
#[no_mangle] pub extern "C" fn rs_udiv128(a_hi: u64, a_lo: u64, d: u64) -> u64 {
    let a = ((a_hi as u128) << 64) | (a_lo as u128);
    (a / (d as u128)) as u64                          // __udivti3
}
#[no_mangle] pub extern "C" fn rs_sort_checksum(p: *mut i32, n: usize) -> i64 {
    let s = unsafe { core::slice::from_raw_parts_mut(p, n) };
    s.sort_unstable();                                // real core sort
    s.iter().enumerate().map(|(i, &x)| (i as i64 + 1) * x as i64).sum()
}
#[no_mangle] pub extern "C" fn rs_bsearch(p: *const i32, n: usize, key: i32) -> i32 {
    let s = unsafe { core::slice::from_raw_parts(p, n) };
    match s.binary_search(&key) { Ok(i) => i as i32, Err(_) => -1 }
}
#[no_mangle] pub extern "C" fn rs_parse_dec() -> i32 { i32::from_str_radix("12345", 10).unwrap_or(-1) }
#[no_mangle] pub extern "C" fn rs_parse_hex() -> i32 { i32::from_str_radix("ff", 16).unwrap_or(-1) }
#[no_mangle] pub extern "C" fn rs_fp_avg(a: i32, b: i32) -> i32 {
    (((a as f32) + (b as f32)) / 2.0) as i32          // f32 add/div + int<->float
}

// ---- core::fmt (formatting machinery; runtime integer Display) ----
use core::fmt::Write;
struct Buf { data: [u8; 32], len: usize }
impl Write for Buf {
    fn write_str(&mut self, s: &str) -> core::fmt::Result {
        for &b in s.as_bytes() { if self.len < self.data.len() { self.data[self.len]=b; self.len+=1; } }
        Ok(())
    }
}
// Format "v=<dec> x=<hex>" of a runtime value into `out` (>=32 bytes); return len.
#[no_mangle] pub extern "C" fn rs_format(out: *mut u8, val: i32) -> usize {
    let mut buf = Buf { data: [0; 32], len: 0 };
    let _ = write!(buf, "v={} x={:x}", val, val);
    let dst = unsafe { core::slice::from_raw_parts_mut(out, buf.len) };
    dst.copy_from_slice(&buf.data[..buf.len]);
    buf.len
}

// ---- trait-object dynamic dispatch (vtable / indirect call) ----
trait Op { fn apply(&self, x: i32) -> i32; }
struct Add(i32);
struct Mul(i32);
impl Op for Add { fn apply(&self, x: i32) -> i32 { x + self.0 } }
impl Op for Mul { fn apply(&self, x: i32) -> i32 { x * self.0 } }
#[no_mangle] pub extern "C" fn rs_dyn(sel: i32, x: i32) -> i32 {
    let a = Add(10);
    let m = Mul(4);
    let op: &dyn Op = if sel == 0 { &a } else { &m };
    op.apply(x)
}
#[no_mangle] pub extern "C" fn rs_sat_add(a: i32, b: i32) -> i32 { a.saturating_add(b) }
