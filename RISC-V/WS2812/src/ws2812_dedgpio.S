# ws2812_dedgpio.S — WS2812 via Dedicated GPIO (CPU GPIO), ESP32-C3

#include "registers.h"

    .section .text
    .global  app_main
    .type    app_main, @function

app_main:
    # TODO: Dedicated GPIO-based WS2812 driver
    j app_main
