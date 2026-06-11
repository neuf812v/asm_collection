# uart.S — minimal serial output over the ESP32-C3 USB-Serial-JTAG (COM13).
#
# No UART peripheral is used; we write straight into the on-chip USB CDC, so the
# text appears on the native-USB COM port — the same cable used for flashing and
# JTAG debugging.  The ROM already configured the USB-Serial-JTAG at boot.
#
# Each byte is written and flushed (WR_DONE) individually: simple and reliable.
# The blink LED is driven by the timer ISR (see timer.S), so it does not matter
# that this output is blocking — a slow/absent reader cannot disturb the blink.
# A bounded wait means a missing host costs only the timeout, then the byte is
# dropped instead of hanging forever.
#
# Public routines (RISC-V calling convention, ilp32):
#   uart_putc   a0 = byte                      send one character
#   uart_puts   a0 = ptr to NUL-terminated str send a string
#   uart_puthex a0 = 32-bit value              send 8 hex digits (MSB first)

#include "registers.h"

# Bounded wait for FIFO space before dropping a byte.  Generous, so a present
# (bursty) reader never loses characters.
#define UART_TX_TIMEOUT  0x80000

    .section .text
    .global uart_putc
    .global uart_puts
    .global uart_puthex
    .type   uart_putc,   @function
    .type   uart_puts,   @function
    .type   uart_puthex, @function

# ── uart_putc ──────────────────────────────────────────────────────────────
# Send the byte in a0: wait (bounded) for FIFO space, write it, flush to host.
uart_putc:
    li   t0, USB_SERIAL_JTAG_EP1_CONF_REG
    li   t2, UART_TX_TIMEOUT
.putc_wait:
    lw   t1, 0(t0)
    andi t1, t1, USB_SERIAL_JTAG_IN_EP_DATA_FREE
    bnez t1, .putc_send
    addi t2, t2, -1
    bnez t2, .putc_wait
    ret                                    # timed out -> drop the byte
.putc_send:
    li   t1, USB_SERIAL_JTAG_EP1_REG
    sw   a0, 0(t1)                          # push byte into the TX FIFO
    li   t1, USB_SERIAL_JTAG_WR_DONE
    sw   t1, 0(t0)                          # flush -> deliver to host
    ret

# ── uart_puts ──────────────────────────────────────────────────────────────
# Send the NUL-terminated string pointed to by a0.
uart_puts:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)
    mv   s0, a0                            # s0 = string pointer (survives calls)
.puts_loop:
    lbu  a0, 0(s0)
    beqz a0, .puts_done                    # stop at NUL
    call uart_putc
    addi s0, s0, 1
    j    .puts_loop
.puts_done:
    lw   ra, 12(sp)
    lw   s0, 8(sp)
    addi sp, sp, 16
    ret

# ── uart_puthex ────────────────────────────────────────────────────────────
# Send the 32-bit value in a0 as 8 hex digits, most-significant nibble first.
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
    call uart_putc
    slli s0, s0, 4                         # shift next nibble up
    addi s1, s1, -1
    bnez s1, .hex_loop
    lw   ra, 12(sp)
    lw   s0, 8(sp)
    lw   s1, 4(sp)
    addi sp, sp, 16
    ret
