# blink.S — Bare-metal GPIO blink (ESP32-C3, 160 MHz)
#
# Wiring: GPIO2 → 220 Ohm resistor → LED → GND
#
# GPIO control registers (bypassing GPIO matrix for simplicity):
#   GPIO_ENABLE_W1TS_REG — enable output direction
#   GPIO_OUT_W1TS_REG    — drive HIGH
#   GPIO_OUT_W1TC_REG    — drive LOW

#include "registers.h"

    .section .text
    .global  app_main
    .type    app_main, @function

# Note: app_main never returns, so it omits a prologue.  It keeps the tick
# counter in s0 (a saved register) because t0-t2 are clobbered by the uart_*
# calls; s0 survives across them.
app_main:
    # Route GPIO2 pad through GPIO matrix (IO_MUX MCU_SEL = 1)
    li   t0, IO_MUX_GPIO2_REG
    li   t1, IO_MUX_MCU_SEL_GPIO
    sw   t1, 0(t0)

    # Configure GPIO2 as output
    li   t0, GPIO_ENABLE_W1TS_REG
    li   t1, BLINK_MASK
    sw   t1, 0(t0)

    li   s0, 0                  # s0 = tick counter

.loop:
    # Print "tick <hex>\r\n" over USB-Serial-JTAG (COM13)
    la   a0, msg_tick
    call uart_puts
    mv   a0, s0
    call uart_puthex
    la   a0, msg_crlf
    call uart_puts
    addi s0, s0, 1

    # LED ON
    li   t0, GPIO_OUT_W1TS_REG
    li   t1, BLINK_MASK
    sw   t1, 0(t0)

    # Delay ~500 ms
    li   t2, DELAY_CYCLES
.delay_on:
    addi t2, t2, -1
    bnez t2, .delay_on

    # LED OFF
    li   t0, GPIO_OUT_W1TC_REG
    li   t1, BLINK_MASK
    sw   t1, 0(t0)

    # Delay ~500 ms
    li   t2, DELAY_CYCLES
.delay_off:
    addi t2, t2, -1
    bnez t2, .delay_off

    j    .loop

    .section .rodata
msg_tick:
    .asciz "tick "
msg_crlf:
    .asciz "\r\n"
