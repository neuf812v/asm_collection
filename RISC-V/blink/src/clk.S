# clk.S — switch the ESP32-C3 CPU clock to 160 MHz (bare metal).
#
# At reset the ROM clocks the CPU from the 40 MHz crystal (SOC_CLK_SEL = XTAL),
# but it leaves the BBPLL running at 480 MHz (it is needed for USB).  So we do
# NOT have to bring the PLL up from scratch — we only:
#   1. select the 160 MHz CPU divider  (CPUPERIOD_SEL = 1  -> PLL/3 = 160 MHz)
#   2. switch the CPU clock source to the PLL (SOC_CLK_SEL = 1)
#
# Both writes are read-modify-write so the other fields (PLL_FREQ_SEL,
# PRE_DIV_CNT, CLK_XTAL_FREQ, …) are preserved.  Uses only t0-t2, no stack, so
# it is safe to call before the stack is set up.

#include "registers.h"

    .section .text
    .global clk_init_160m
    .type   clk_init_160m, @function

clk_init_160m:
    # ── 1. CPUPERIOD_SEL = 1 (160 MHz) ──
    li   t0, SYSTEM_CPU_PER_CONF_REG
    lw   t1, 0(t0)
    andi t1, t1, ~SYSTEM_CPUPERIOD_SEL_MASK   # clear bits [1:0]
    ori  t1, t1, SYSTEM_CPUPERIOD_160M        # set 160 MHz
    sw   t1, 0(t0)

    # ── 2. SOC_CLK_SEL = PLL ──
    li   t0, SYSTEM_SYSCLK_CONF_REG
    lw   t1, 0(t0)
    li   t2, ~SYSTEM_SOC_CLK_SEL_MASK         # mask out bits [11:10]
    and  t1, t1, t2
    li   t2, SYSTEM_SOC_CLK_SEL_PLL           # select PLL
    or   t1, t1, t2
    sw   t1, 0(t0)

    ret
