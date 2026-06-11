# blink.S — timer-interrupt blink + live UART output (ESP32-C3, 160 MHz)
#
# Wiring: GPIO2 → 220 Ohm resistor → LED → GND
#
# The LED is toggled by the TIMG0 timer ISR (see timer.S), so its timing is
# exact regardless of what the main loop does.  The main loop is therefore free
# to print a tick counter over the USB-Serial-JTAG with a blocking, reliable
# UART — even if no host is reading — without distorting the blink.

#include "registers.h"

    .section .text
    .global  app_main
    .type    app_main, @function

app_main:
    # Route GPIO2 pad through GPIO matrix (IO_MUX MCU_SEL = 1)
    li   t0, IO_MUX_GPIO2_REG
    li   t1, IO_MUX_MCU_SEL_GPIO
    sw   t1, 0(t0)

    # Configure GPIO2 as output
    li   t0, GPIO_ENABLE_W1TS_REG
    li   t1, BLINK_MASK
    sw   t1, 0(t0)

    # Start the timer interrupt that toggles the LED.
    call irq_init

    li   s0, 0                  # s0 = tick counter (survives uart_* calls)

.loop:
    # Print "tick <hex>\r\n" — blocking is fine, the LED is on the timer ISR.
    la   a0, msg_tick
    call uart_puts
    mv   a0, s0
    call uart_puthex
    la   a0, msg_crlf
    call uart_puts
    addi s0, s0, 1

    # Sleep until the next interrupt (the 0.5 s timer), then print again.
    wfi
    j    .loop

    .section .rodata
msg_tick:
    .asciz "tick "
msg_crlf:
    .asciz "\r\n"
