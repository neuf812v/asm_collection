# timer.S — TIMG0 Timer0 periodic interrupt that toggles the LED.
#
# This decouples the blink timing from the main loop: the LED is toggled inside
# the timer ISR (precise, hardware-paced), so the main loop is free to do slow,
# blocking work (e.g. UART output) without distorting the blink.
#
# ESP32-C3 interrupt path:
#   TIMG0-T0 alarm --> Interrupt Matrix (map source -> CPU int line N)
#                  --> CPU interrupt controller (enable/type/priority/threshold)
#                  --> RISC-V trap (mstatus.MIE) --> mtvec (direct) --> timer_isr
#
# Public:  irq_init   set up the timer + interrupt and start it (call once)
# The ISR is installed via mtvec; it is not called directly.

#include "registers.h"

    .section .text

# ── irq_init ───────────────────────────────────────────────────────────────
# Configure TIMG0-T0 for a 0.5 s periodic alarm, route its interrupt to a CPU
# interrupt line, install the handler, and globally enable IRQs.  Uses t0-t2.
    .global irq_init
    .type   irq_init, @function
irq_init:
    # ── TIMG0: force the register clock on, keep the timer's functional clock ──
    # TIMG_TIMER_CLK_IS_ACTIVE (bit30) defaults to 1 and gates the counter; a
    # blind write of CLK_EN alone would clear it and the timer would never count.
    li   t0, TIMG0_REGCLK_REG
    li   t1, (TIMG_CLK_EN | TIMG_TIMER_CLK_IS_ACTIVE)
    sw   t1, 0(t0)

    # ── Reset the counter to 0 (LOADLO/HI = 0, then trigger LOAD) ──
    li   t0, TIMG0_T0LOADLO_REG
    sw   zero, 0(t0)
    li   t0, TIMG0_T0LOADHI_REG
    sw   zero, 0(t0)
    li   t0, TIMG0_T0LOAD_REG
    li   t1, 1
    sw   t1, 0(t0)                 # write triggers load of LOADLO/HI into counter

    # ── Alarm value = 0.5 s worth of ticks ──
    li   t0, TIMG0_T0ALARMLO_REG
    li   t1, TIMER_ALARM_TICKS
    sw   t1, 0(t0)
    li   t0, TIMG0_T0ALARMHI_REG
    sw   zero, 0(t0)

    # ── Enable the TIMG0-T0 interrupt at the source ──
    li   t0, TIMG0_INT_ENA_REG
    li   t1, TIMG_T0_INT_BIT
    sw   t1, 0(t0)

    # ── Interrupt Matrix: route TIMG0-T0 -> CPU interrupt line N ──
    li   t0, INTERRUPT_CORE0_TG_T0_INT_MAP_REG
    li   t1, TIMER_CPU_INT_NUM
    sw   t1, 0(t0)

    # ── CPU int N: level-triggered (clear its TYPE bit) ──
    li   t0, INTERRUPT_CORE0_CPU_INT_TYPE_REG
    lw   t1, 0(t0)
    li   t2, ~(1 << TIMER_CPU_INT_NUM)
    and  t1, t1, t2
    sw   t1, 0(t0)

    # ── CPU int N: priority, and threshold = 0 (allow priority >= 1) ──
    li   t0, INTERRUPT_PRIO_REG(TIMER_CPU_INT_NUM)
    li   t1, TIMER_CPU_INT_PRIO
    sw   t1, 0(t0)
    li   t0, INTERRUPT_CORE0_CPU_INT_THRESH_REG
    sw   zero, 0(t0)

    # ── CPU int N: enable ──
    li   t0, INTERRUPT_CORE0_CPU_INT_ENABLE_REG
    lw   t1, 0(t0)
    ori  t1, t1, (1 << TIMER_CPU_INT_NUM)
    sw   t1, 0(t0)

    # ── Install the vector table (mtvec, VECTORED mode: low 2 bits = 01) ──
    # The ESP32-C3 interrupt controller requires vectored mode: on interrupt N
    # the core jumps to (mtvec_base + 4*N).  Entry 7 is our timer handler.
    la   t0, _vector_table
    ori  t0, t0, 1                # MODE = 1 (vectored)
    csrw mtvec, t0

    # ── Start the timer: EN | INCREASE | AUTORELOAD | ALARM_EN | divider ──
    li   t0, TIMG0_T0CONFIG_REG
    li   t1, (TIMG_T0_EN | TIMG_T0_INCREASE | TIMG_T0_AUTORELOAD | TIMG_T0_ALARM_EN | (TIMER_DIVIDER << TIMG_T0_DIVIDER_S))
    sw   t1, 0(t0)

    # ── Globally enable machine interrupts (mstatus.MIE, bit 3) ──
    csrsi mstatus, 0x8
    ret

# ── timer_isr ──────────────────────────────────────────────────────────────
# Trap handler (mtvec target).  Toggles GPIO2, clears the timer interrupt and
# re-arms the alarm, then returns with mret.  Saves only the temporaries it
# uses; mepc/mstatus are preserved by hardware across mret.
    .align 2
    .global timer_isr
    .type   timer_isr, @function
timer_isr:
    addi sp, sp, -16
    sw   t0, 0(sp)
    sw   t1, 4(sp)
    sw   t2, 8(sp)

    # Toggle GPIO2 using a state flag + W1TS/W1TC (do not read GPIO_OUT — its
    # read-back is unreliable under the GPIO-matrix routing, which would pin the
    # pin HIGH).  led_state lives in .bss (zeroed at startup).
    la   t0, led_state
    lw   t1, 0(t0)
    xori t1, t1, 1
    sw   t1, 0(t0)
    li   t2, BLINK_MASK
    beqz t1, .led_off
    li   t0, GPIO_OUT_W1TS_REG    # state now 1 -> drive HIGH
    sw   t2, 0(t0)
    j    .led_done
.led_off:
    li   t0, GPIO_OUT_W1TC_REG    # state now 0 -> drive LOW
    sw   t2, 0(t0)
.led_done:

    # Clear the TIMG0-T0 interrupt flag (deasserts the level)
    li   t0, TIMG0_INT_CLR_REG
    li   t1, TIMG_T0_INT_BIT
    sw   t1, 0(t0)

    # Re-arm the alarm (ALARM_EN self-clears when it fires)
    li   t0, TIMG0_T0CONFIG_REG
    lw   t1, 0(t0)
    li   t2, TIMG_T0_ALARM_EN
    or   t1, t1, t2
    sw   t1, 0(t0)

    lw   t0, 0(sp)
    lw   t1, 4(sp)
    lw   t2, 8(sp)
    addi sp, sp, 16
    mret

# ── Vector table (vectored mtvec) ──────────────────────────────────────────
# In vectored mode the core jumps to base + 4*cause: entry 0 handles synchronous
# exceptions, entry N handles CPU interrupt N.  Each slot is a full 4-byte `j`
# (no compression), so the 4*N stride is exact.  Only entry 7 (our timer line)
# is meaningful; everything else parks in an infinite loop to catch surprises.
    .section .text
    .balign 0x100
    .option push
    .option norvc
    .global _vector_table
_vector_table:
    .rept 7
    j    _unhandled
    .endr
    j    timer_isr               # entry 7 — TIMER_CPU_INT_NUM
    .rept 24
    j    _unhandled
    .endr
    .option pop
_unhandled:
    j    _unhandled

    .section .bss
    .align 2
led_state:
    .word 0
