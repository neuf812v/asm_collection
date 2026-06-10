# uart.S — minimal serial output over the ESP32-C3 USB-Serial-JTAG (COM13).
#
# No UART peripheral is used; we write straight into the on-chip USB CDC, so the
# text appears on the native-USB COM port — the same cable used for flashing and
# JTAG debugging.  The ROM already configured the USB-Serial-JTAG at boot, so we
# only push bytes and flush.
#
# IMPORTANT — non-blocking by design.  If no host is reading the port the IN
# endpoint never drains, so we must NOT busy-wait long: each byte waits only a
# short bounded time for FIFO space, then is dropped.  And we flush ONCE per
# string (not per byte), so the time spent here stays sub-millisecond and does
# not distort the caller's timing (e.g. the blink loop).  For exact timing the
# proper answer is a timer interrupt, not output in the timing path.
#
# Public routines (RISC-V calling convention, ilp32):
#   uart_putc   a0 = byte                      send one character + flush
#   uart_puts   a0 = ptr to NUL-terminated str send a string, flush once
#   uart_puthex a0 = 32-bit value              send 8 hex digits, flush once

#include "registers.h"

# Cap on how long to wait for FIFO space before dropping a byte.  Generous, so
# a present (but bursty) reader never loses characters; if no host is attached
# the byte is dropped after the timeout.  This is only safe OUTSIDE a timing
# path — e.g. the one-shot boot banner (which fits in the 64-byte FIFO and never
# even hits the wait).  Do not call this from the blink delay loop.
#define UART_TX_TIMEOUT  0x40000

    .section .text
    .global uart_putc
    .global uart_puts
    .global uart_puthex
    .type   uart_putc,   @function
    .type   uart_puts,   @function
    .type   uart_puthex, @function

# ── uart_putc_raw (internal) ───────────────────────────────────────────────
# Push the byte in a0 into the TX FIFO, waiting (briefly) for space.  Does NOT
# flush.  Clobbers t0-t2 only, no stack, so callers may use it in a loop.
uart_putc_raw:
    li   t0, USB_SERIAL_JTAG_EP1_CONF_REG
    li   t2, UART_TX_TIMEOUT
.raw_wait:
    lw   t1, 0(t0)
    andi t1, t1, USB_SERIAL_JTAG_IN_EP_DATA_FREE
    bnez t1, .raw_send
    addi t2, t2, -1
    bnez t2, .raw_wait
    ret                                    # no space, no reader -> drop byte
.raw_send:
    li   t1, USB_SERIAL_JTAG_EP1_REG
    sw   a0, 0(t1)                          # push byte into the TX FIFO
    ret

# ── uart_flush (internal) ──────────────────────────────────────────────────
# Set WR_DONE to deliver the buffered bytes to the host.  Clobbers t0-t1.
uart_flush:
    li   t0, USB_SERIAL_JTAG_EP1_CONF_REG
    li   t1, USB_SERIAL_JTAG_WR_DONE
    sw   t1, 0(t0)
    ret

# ── uart_putc ──────────────────────────────────────────────────────────────
# Send one byte (a0) and flush it.
uart_putc:
    addi sp, sp, -16
    sw   ra, 12(sp)
    call uart_putc_raw
    call uart_flush
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

# ── uart_puts ──────────────────────────────────────────────────────────────
# Send the NUL-terminated string pointed to by a0, then flush once.
uart_puts:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)
    mv   s0, a0                            # s0 = string pointer (survives calls)
.puts_loop:
    lbu  a0, 0(s0)
    beqz a0, .puts_done                    # stop at NUL
    call uart_putc_raw
    addi s0, s0, 1
    j    .puts_loop
.puts_done:
    call uart_flush
    lw   ra, 12(sp)
    lw   s0, 8(sp)
    addi sp, sp, 16
    ret

# ── uart_puthex ────────────────────────────────────────────────────────────
# Send the 32-bit value in a0 as 8 hex digits (MSB first), then flush once.
uart_puthex:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)
    sw   s1, 4(sp)
    mv   s0, a0                            # s0 = value being shifted out
    li   s1, 8                             # s1 = nibbles remaining
.hex_loop:
    srli a0, s0, 28                        # take the top nibble
    andi a0, a0, 0xF
    li   t0, 10
    blt  a0, t0, .hex_digit
    addi a0, a0, 'a' - 10                  # 10..15 -> 'a'..'f'
    j    .hex_emit
.hex_digit:
    addi a0, a0, '0'                       # 0..9 -> '0'..'9'
.hex_emit:
    call uart_putc_raw
    slli s0, s0, 4                         # shift next nibble up
    addi s1, s1, -1
    bnez s1, .hex_loop
    call uart_flush
    lw   ra, 12(sp)
    lw   s0, 8(sp)
    lw   s1, 4(sp)
    addi sp, sp, 16
    ret
