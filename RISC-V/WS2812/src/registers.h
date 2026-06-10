#pragma once

/* ESP-IDF headers — safe for assembler via include/stdint.h stub */
#include "soc/soc.h"             /* REG_TIMG_BASE                              */
#include "soc/timer_group_reg.h" /* TIMG_WDTCONFIG0_REG(i), TIMG_WDTWPROTECT_REG(i) */
#include "soc/rtc_cntl_reg.h"   /* RTC_CNTL_WDTCONFIG0_REG, RTC_CNTL_WDTWPROTECT_REG */
#include "soc/gpio_reg.h"        /* GPIO_OUT_W1TS_REG, GPIO_OUT_W1TC_REG, GPIO_ENABLE_W1TS_REG */

/* WDT write-protect unlock key */
#define WDT_WRITE_PROTECT_KEY  0x50D83AA1

/* WS2812 pin */
#define WS2812_GPIO  8
#define WS2812_MASK  (1 << WS2812_GPIO)

/* WS2812 timing at 160 MHz (1 cycle = 6.25 ns) */
#define CYCLES_T0H   60
#define CYCLES_T0L   132
#define CYCLES_T1H   124
#define CYCLES_T1L   68
#define CYCLES_RES   8000
