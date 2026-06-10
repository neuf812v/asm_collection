/* Bare-metal linker script for ESP32-C3 — DIRECT BOOT mode.
 *
 * No second-stage bootloader is involved.  The ROM bootloader detects the
 * direct-boot magic (0xaedb041d twice) at flash offset 0x0, maps the whole
 * flash to 0x42000000 and jumps to flash offset 8 (= 0x42000008).  The
 * application then executes in place (XIP) from memory-mapped flash.
 *
 * Activation conditions (all true on a stock DevKit):
 *   - secure boot disabled
 *   - EFUSE_DIS_LEGACY_SPI_BOOT not burned
 *   - no valid ESP image header (0xE9) at flash 0x0  ← our first byte is 0x1d
 *
 * Flash layout (raw binary written at 0x0):
 *   +0x00  magic  0xaedb041d
 *   +0x04  magic  0xaedb041d
 *   +0x08  _start                ← ROM jumps here (vaddr 0x42000008)
 *   ...    .text / .rodata        (executed/read in place from flash via cache)
 *
 *   .bss + stack live in DRAM (SRAM, no cache, zeroed by _start).
 *   There is no .data section — the blink uses only immediates.
 */

ENTRY(_start)

MEMORY
{
    /* Memory-mapped flash (XIP).  ROM maps flash 0x0 -> 0x42000000. */
    flash (RX) : ORIGIN = 0x42000000, LENGTH = 0x400000

    /* General-purpose SRAM for BSS and stack. */
    dram  (RW) : ORIGIN = 0x3FC80000, LENGTH = 0x50000
}

SECTIONS
{
    .text :
    {
        /* .text.entry holds the magic words + _start, so _start lands
         * exactly at flash offset 8 (= 0x42000008) where the ROM jumps. */
        *(.text.entry)
        *(.text*)
        *(.rodata*)
    } > flash

    .bss (NOLOAD) :
    {
        _bss_start = .;
        *(.bss*)
        *(COMMON)
        _bss_end = .;
    } > dram

    _stack_top = ORIGIN(dram) + LENGTH(dram);

    /DISCARD/ :
    {
        *(.comment)
        *(.riscv.attributes)
        *(.eh_frame*)
    }
}
