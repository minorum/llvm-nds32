; RUN: llc -mtriple=nds32be-unknown-none-elf -relocation-model=pic \
; RUN:   -verify-machineinstrs < %s | FileCheck %s --check-prefix=PIC
; RUN: llc -mtriple=nds32be-unknown-none-elf < %s | FileCheck %s --check-prefix=STATIC

@local = internal global i32 0
@ext = external global i32
@tv = thread_local global i32 0

; A local symbol in PIC is reached as $gp + GOTOFF(sym).
; PIC-LABEL: rd_local:
; PIC: sethi $r{{[0-9]+}}, hi20gotoff(local)
; PIC: ori $r{{[0-9]+}}, $r{{[0-9]+}}, lo12gotoff(local)
; STATIC-LABEL: rd_local:
; STATIC: hi20(local)
define i32 @rd_local() {
  %v = load i32, ptr @local
  ret i32 %v
}

; A preemptible symbol is loaded from its GOT entry at $gp + GOT(sym).
; PIC-LABEL: rd_ext:
; PIC: sethi $r{{[0-9]+}}, hi20got(ext)
; PIC: ori $r{{[0-9]+}}, $r{{[0-9]+}}, lo12got(ext)
define i32 @rd_ext() {
  %v = load i32, ptr @ext
  ret i32 %v
}

; Thread-local (local-exec): $tp ($r25) + tpoff(sym).
; PIC-LABEL: rd_tls:
; PIC: sethi $r{{[0-9]+}}, hi20tpoff(tv)
; PIC: ori $r{{[0-9]+}}, $r{{[0-9]+}}, lo12tpoff(tv)
; STATIC-LABEL: rd_tls:
; STATIC: hi20tpoff(tv)
define i32 @rd_tls() {
  %v = load i32, ptr @tv
  ret i32 %v
}
