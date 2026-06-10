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

/* USB-Serial-JTAG — the chip's on-chip USB CDC, exposed as the native-USB COM
 * port (COM13).  Used for printf-style debug output straight from asm, on the
 * same cable as flashing/JTAG.  See uart.S.
 *   EP1_REG       : write a byte -> TX FIFO
 *   EP1_CONF_REG  : WR_DONE (bit0, flush to host), IN_EP_DATA_FREE (bit1, RO) */
#define USB_SERIAL_JTAG_EP1_REG          0x60043000
#define USB_SERIAL_JTAG_EP1_CONF_REG     0x60043004
#define USB_SERIAL_JTAG_WR_DONE          (1 << 0)
#define USB_SERIAL_JTAG_IN_EP_DATA_FREE  (1 << 1)

/* Blink half-period.  In direct boot the CPU runs at the ROM default clock
 * and code executes XIP from flash, so the busy loop is ~200 ns/iteration
 * (measured: 40,000,000 iters = 8.0 s).  2,500,000 iters ≈ 0.5 s. */
#define DELAY_CYCLES  2500000
