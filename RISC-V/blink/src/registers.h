#pragma once

#include "soc/soc.h"
#include "soc/timer_group_reg.h"
#include "soc/rtc_cntl_reg.h"
#include "soc/gpio_reg.h"

#define WDT_WRITE_PROTECT_KEY  0x50D83AA1

/* Super Watchdog (SWD) — a separate RTC watchdog not covered by the WDT
 * config registers above.  In direct boot it bites ~once a second and
 * resets the chip (rst:0x12 SUPER_WDT_RST).  Unlock with this key, then
 * set AUTO_FEED_EN so it keeps feeding itself and never fires. */
#define SWD_WRITE_PROTECT_KEY  0x8F1D312A
#define SWD_AUTO_FEED_EN       (1 << 31)

/* IO_MUX_GPIO2_REG: DR_REG_IO_MUX_BASE(0x60009000) + 0x0C
 * MCU_SEL field [14:12] = 1 routes the pad through the GPIO matrix */
#define IO_MUX_GPIO2_REG       0x6000900C
#define IO_MUX_MCU_SEL_GPIO    (1 << 12)

/* GPIO for LED — connect LED through a 220 Ohm resistor to GND */
#define BLINK_GPIO   2
#define BLINK_MASK   (1 << BLINK_GPIO)

/* ── Hardware timer: TIMG0 Timer0 ──────────────────────────────────────────
 * Drives the LED from a timer interrupt so blink timing is independent of what
 * the main loop does (e.g. blocking UART output).  Clock = APB (80 MHz at
 * 160 MHz CPU) / divider.  divider 80 -> 1 MHz tick; alarm 500000 -> 0.5 s.
 *
 * The TIMG_T0_xxx and TIMG_CLK_EN bit macros and GPIO_OUT_REG come from the
 * included soc headers; only the constants below are project-local. */
#define TIMG0_T0CONFIG_REG    0x6001F000
#define TIMG0_T0ALARMLO_REG   0x6001F010
#define TIMG0_T0ALARMHI_REG   0x6001F014
#define TIMG0_T0LOADLO_REG    0x6001F018
#define TIMG0_T0LOADHI_REG    0x6001F01C
#define TIMG0_T0LOAD_REG      0x6001F020
#define TIMG0_INT_ENA_REG     0x6001F070
#define TIMG0_INT_CLR_REG     0x6001F07C
#define TIMG0_REGCLK_REG      0x6001F0FC
#define TIMG_T0_INT_BIT       (1 << 0)    /* T0 bit in INT_ENA/CLR/ST */
#define TIMER_DIVIDER         80          /* 80 MHz / 80 = 1 MHz tick */
#define TIMER_ALARM_TICKS     500000      /* 500000 us = 0.5 s */

/* ── Interrupt matrix + CPU interrupt controller (core 0) ──────────────────
 * Route the TIMG0-T0 source to a CPU interrupt line, set it level-triggered
 * with a priority above the threshold, and enable it. */
#define INTERRUPT_CORE0_TG_T0_INT_MAP_REG  0x600C2080
#define INTERRUPT_CORE0_CPU_INT_ENABLE_REG 0x600C2104
#define INTERRUPT_CORE0_CPU_INT_TYPE_REG   0x600C2108
#define INTERRUPT_CORE0_CPU_INT_CLEAR_REG  0x600C210C
#define INTERRUPT_CORE0_CPU_INT_THRESH_REG 0x600C2194
#define INTERRUPT_PRIO_REG(n)              (0x600C2114 + (n) * 4)
#define TIMER_CPU_INT_NUM     7            /* CPU interrupt line we use (1..31) */
#define TIMER_CPU_INT_PRIO    1            /* priority (must exceed threshold 0) */

/* System clock — switch the CPU from the 40 MHz XTAL to the BBPLL.
 * The ROM leaves the BBPLL running at 480 MHz (PLL_FREQ_SEL=1) but clocks the
 * CPU from XTAL (SOC_CLK_SEL=0).  Selecting PLL with CPUPERIOD_SEL=1 gives
 * 480/3 = 160 MHz.  See clk.S.
 *   CPU_PER_CONF.CPUPERIOD_SEL [1:0] : 0=80 MHz, 1=160 MHz
 *   SYSCLK_CONF.SOC_CLK_SEL    [11:10]: 0=XTAL, 1=PLL, 2=RC_FAST */
#define SYSTEM_CPU_PER_CONF_REG   0x600C0008
#define SYSTEM_SYSCLK_CONF_REG    0x600C0058
#define SYSTEM_CPUPERIOD_SEL_MASK 0x3
#define SYSTEM_CPUPERIOD_160M     0x1
#define SYSTEM_SOC_CLK_SEL_MASK   (0x3 << 10)
#define SYSTEM_SOC_CLK_SEL_PLL    (0x1 << 10)

/* USB-Serial-JTAG — the chip's on-chip USB CDC, exposed as the native-USB COM
 * port (COM13).  Used for printf-style debug output straight from asm, on the
 * same cable as flashing/JTAG.  See uart.S.
 *   EP1_REG       : write a byte -> TX FIFO
 *   EP1_CONF_REG  : WR_DONE (bit0, flush to host), IN_EP_DATA_FREE (bit1, RO) */
#define USB_SERIAL_JTAG_EP1_REG          0x60043000
#define USB_SERIAL_JTAG_EP1_CONF_REG     0x60043004
#define USB_SERIAL_JTAG_WR_DONE          (1 << 0)
#define USB_SERIAL_JTAG_IN_EP_DATA_FREE  (1 << 1)

