# ws2812_spi.S — WS2812 via SPI + DMA, ESP32-C3

#include "registers.h"

    .section .text
    .global  app_main
    .type    app_main, @function

app_main:
    # TODO: SPI/DMA-based WS2812 driver
    j app_main
