# uart.S — minimal serial output over the ESP32-C3 USB-Serial-JTAG (COM13).
#
# No UART peripheral is used; we write straight into the on-chip USB CDC, so the
# text appears on the native-USB COM port — the same cable used for flashing and
# JTAG debugging.  The ROM already configured the USB-Serial-JTAG at boot, so we
# only push bytes and flush.
#
# Public routines (RISC-V calling convention, ilp32):
#   uart_putc   a0 = byte                      send one character
#   uart_puts   a0 = ptr to NUL-terminated str send a string
#   uart_puthex a0 = 32-bit value              send 8 hex digits (MSB first)
#
# Registers: a0 is the argument (clobbered); t0-t3 are scratch.  uart_puts and
# uart_puthex preserve their working pointer/counter in saved registers across
# the calls to uart_putc, and restore ra/s-regs from the stack.

#include "registers.h"

    .section .text
    .global uart_putc
    .global uart_puts
    .global uart_puthex
    .type   uart_putc,   @function
    .type   uart_puts,   @function
    .type   uart_puthex, @function

# ── uart_putc ─────────────────────────────────────────────────────────────
# Send the byte in a0.  Waits (bounded) until the IN endpoint has space, writes
# the byte, then sets WR_DONE to flush it to the host.  The bounded wait means
# that if no terminal is attached (FIFO never drains) we drop the byte instead
# of hanging the program.
uart_putc:
    li   t0, USB_SERIAL_JTAG_EP1_CONF_REG
    li   t2, 0x80000                       # ~timeout: give up if no reader
.putc_wait:
    lw   t1, 0(t0)
    andi t1, t1, USB_SERIAL_JTAG_IN_EP_DATA_FREE
    bnez t1, .putc_send                    # space available -> send
    addi t2, t2, -1
    bnez t2, .putc_wait
    ret                                    # timed out -> drop the byte
.putc_send:
    li   t1, USB_SERIAL_JTAG_EP1_REG
    sw   a0, 0(t1)                          # push byte into the TX FIFO
    li   t1, USB_SERIAL_JTAG_WR_DONE
    sw   t1, 0(t0)                          # flush -> deliver to host
    ret

# ── uart_puts ─────────────────────────────────────────────────────────────
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

# ── uart_puthex ───────────────────────────────────────────────────────────
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
