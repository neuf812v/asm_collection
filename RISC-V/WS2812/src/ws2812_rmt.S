# ws2812_rmt.S — WS2812 via RMT (Remote Control Transceiver), ESP32-C3

#include "registers.h"

    .section .text
    .global  app_main
    .type    app_main, @function

app_main:
    # TODO: RMT-based WS2812 driver
    j app_main
