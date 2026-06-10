/* Bare-metal linker script for ESP32-C3
 *
 * ESP32-C3 memory map:
 *   IRAM: 0x4037C000, 256 KB  — code runs here (no cache misses)
 *   DRAM: 0x3FC80000, 320 KB  — stack and data
 *
 * Bootloader copies code from flash to IRAM, then jumps to _start.
 * Ideal for WS2812: precise timing without cache stalls.
 */

ENTRY(_start)

MEMORY
{
    iram (RWX) : ORIGIN = 0x4037C000, LENGTH = 0x40000   /* 256 KB IRAM */
    dram (RW)  : ORIGIN = 0x3FC80000, LENGTH = 0x50000   /* 320 KB DRAM */
}

SECTIONS
{
    .text :
    {
        *(.text.entry)   /* startup.S first */
        *(.text*)
        *(.rodata*)
    } > iram

    .data :
    {
        _data_start = .;
        *(.data*)
        _data_end = .;
    } > dram

    .bss (NOLOAD) :
    {
        _bss_start = .;
        *(.bss*)
        *(COMMON)
        _bss_end = .;
    } > dram

    /* Stack at the end of DRAM */
    _stack_top = ORIGIN(dram) + LENGTH(dram);
}
