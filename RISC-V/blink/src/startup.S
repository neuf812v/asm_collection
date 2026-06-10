# startup.S — Bare-metal startup for ESP32-C3 (RISC-V RV32IMC), DIRECT BOOT.
#
# No second-stage bootloader.  The ROM bootloader finds the direct-boot magic
# (0xaedb041d twice) at flash offset 0, maps flash to 0x42000000 and jumps to
# offset 8 — which is exactly where _start sits, right after the two magic
# words below.  Code executes in place (XIP) from memory-mapped flash.

#include "registers.h"

    .section .text.entry, "ax"

    # ── Direct-boot magic (read by the ROM bootloader at flash 0x0) ──
    # Two copies of 0xaedb041d occupy bytes 0..7; _start follows at offset 8.
    .global  _magic
_magic:
    .word   0xAEDB041D
    .word   0xAEDB041D

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

    # ── 3b. Disable Super WDT (auto-feed) ──
    # Without this the chip resets ~1x/s with rst:0x12 (SUPER_WDT_RST).
    li   t0, RTC_CNTL_SWD_WPROTECT_REG   # unlock
    li   t1, SWD_WRITE_PROTECT_KEY
    sw   t1, 0(t0)
    li   t0, RTC_CNTL_SWD_CONF_REG       # set AUTO_FEED_EN (bit 31)
    lw   t1, 0(t0)
    li   t2, SWD_AUTO_FEED_EN
    or   t1, t1, t2
    sw   t1, 0(t0)
    li   t0, RTC_CNTL_SWD_WPROTECT_REG   # re-lock
    sw   zero, 0(t0)

    # ── 3c. Switch CPU to 160 MHz (PLL) ──
    # Self-contained (t0-t2, no stack), so it is fine to call here.
    call clk_init_160m

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

    # ── 6. Greeting over USB-Serial-JTAG (COM13) ──
    la   a0, msg_boot
    call uart_puts

    # ── 7. Call app_main ──
    call app_main

.hang:
    j    .hang

    .section .rodata
msg_boot:
    .asciz "\r\nESP32-C3 bare-metal blink (direct boot)\r\n"
