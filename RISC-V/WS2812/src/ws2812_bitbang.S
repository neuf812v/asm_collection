# ws2812_bitbang.S — WS2812 driver, bare-metal RISC-V (ESP32-C3, 160 MHz)

#include "registers.h"

    .section .text
    .global  app_main
    .type    app_main, @function

# void app_main(void)
app_main:
    # TODO: your code here
    j app_main
