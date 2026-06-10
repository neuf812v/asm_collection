# startup.S — Bare-metal startup for ESP32-C3 (RISC-V RV32IMC)

#include "registers.h"

    .section .text.entry
    .global  _start
    .type    _start, @function

_start:
    # ── 1. Disable TIMG0 WDT ──
    li   t0, TIMG_WDTWPROTECT_REG(0)
    li   t1, WDT_WRITE_PROTECT_KEY
    sw   t1, 0(t0)
    li   t0, TIMG_WDTCONFIG0_REG(0)
    sw   zero, 0(t0)

    # ── 2. Disable TIMG1 WDT ──
    li   t0, TIMG_WDTWPROTECT_REG(1)
    li   t1, WDT_WRITE_PROTECT_KEY
    sw   t1, 0(t0)
    li   t0, TIMG_WDTCONFIG0_REG(1)
    sw   zero, 0(t0)

    # ── 3. Disable RTC WDT ──
    li   t0, RTC_CNTL_WDTWPROTECT_REG
    li   t1, WDT_WRITE_PROTECT_KEY
    sw   t1, 0(t0)
    li   t0, RTC_CNTL_WDTCONFIG0_REG
    sw   zero, 0(t0)

    # ── 4. Set up stack ──
    la   sp, _stack_top

    # ── 5. Zero BSS ──
    la   t0, _bss_start
    la   t1, _bss_end
.bss_loop:
    bge  t0, t1, .bss_done
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    .bss_loop
.bss_done:

    # ── 6. Call app_main ──
    call app_main

.hang:
    j    .hang
