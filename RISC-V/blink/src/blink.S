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

# Clean, symmetric blink.  No serial output in the timing path — that distorts
# the period (see uart.S / the timer-interrupt version for live output).
app_main:
    # Route GPIO2 pad through GPIO matrix (IO_MUX MCU_SEL = 1)
    li   t0, IO_MUX_GPIO2_REG
    li   t1, IO_MUX_MCU_SEL_GPIO
    sw   t1, 0(t0)

    # Configure GPIO2 as output
    li   t0, GPIO_ENABLE_W1TS_REG
    li   t1, BLINK_MASK
    sw   t1, 0(t0)

.loop:
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
