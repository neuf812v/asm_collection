# blink — bare-metal RISC-V on ESP32-C3

A minimal, fully standalone assembly program for the **ESP32-C3-DevKitM-1**.
No ESP-IDF, no FreeRTOS, no runtime — just RISC-V (RV32IMC) assembly that runs
straight from reset and blinks an LED on **GPIO2** at ~1 Hz.

It boots via the ESP32-C3 ROM **Direct Boot** feature, bypassing the ESP-IDF
second-stage bootloader entirely. The code executes in place (XIP) from
memory-mapped flash at `0x42000000`.

> Full debugging story and rationale (in Ukrainian):
> [`../../inf/ESP32-C3_asm_Issues.md`](../../inf/ESP32-C3_asm_Issues.md)

---

## Wiring

```
GPIO2 ──[ 220 Ω ]──▶|── GND
                   LED
```

`GPIO2 → 220 Ω resistor → LED anode`, LED cathode → `GND`.

---

## Requirements

- **ESP32-C3** with Direct Boot available (silicon rev ≥ 3; secure boot off,
  `DIS_LEGACY_SPI_BOOT` efuse not burned). A stock DevKit qualifies.
- **riscv32-esp-elf** GCC toolchain (ships with ESP-IDF / `.espressif`).
- **esptool** (from the ESP-IDF Python env) for flashing.
- **GNU make** (`mingw32-make` on Windows).

Toolchain/Python paths are resolved in the `Makefile` from `%USERPROFILE%`.
Adjust them there if your install differs.

---

## Build & flash

```sh
mingw32-make                    # build  -> blink.bin (raw direct-boot image)
mingw32-make flash PORT=COM16   # flash raw image to 0x0
```

Other targets:

```sh
mingw32-make erase PORT=COM16   # full chip erase (clears old bootloader/partitions)
mingw32-make dis                # disassemble blink.elf
mingw32-make clean              # remove build artifacts
```

`blink.bin` is a **raw** binary (built with `objcopy -O binary`, *not*
`esptool elf2image`). It starts with the Direct Boot magic and is flashed at
offset `0x0` — there is **no** second-stage bootloader and **no** partition
table involved.

---

## Project structure

| File | Purpose |
|------|---------|
| `link.ld` | Linker script — `.text`/`.rodata` in XIP flash `0x42000000`, `.bss`+stack in DRAM |
| `src/startup.S` | Direct Boot magic + `_start`: disable all watchdogs, set up stack, zero BSS, call `app_main` |
| `src/blink.S` | `app_main`: route GPIO2, enable output, toggle with busy-loop delays |
| `src/registers.h` | Register addresses, watchdog keys, `DELAY_CYCLES`, `BLINK_*` |
| `Makefile` | Build (`objcopy`), `flash` (0x0), `erase`, `dis` |

---

## How it works (short version)

1. **ROM bootloader** reads flash `0x0`. The first byte is `0x1D` (not the
   `0xE9` ESP-image magic), so the ROM takes the **Direct Boot** path.
2. It sees the magic `0xAEDB041D` twice in the first 8 bytes, maps flash to
   `0x42000000`, and jumps to offset 8 → `0x42000008`, where `_start` lives.
3. `_start` disables **TIMG0, TIMG1, RTC and Super** watchdogs, sets up the
   stack, zeroes `.bss`, and calls `app_main`.
4. `app_main` routes GPIO2 through IO_MUX, enables output, and toggles it with
   calibrated busy-loop delays.

The two magic words are emitted at the very start of `.text.entry` in
`startup.S`, guaranteeing `_start` lands exactly at `0x42000008`.

> Disabling the **Super Watchdog** is mandatory. The regular TIMG/RTC watchdog
> registers do not cover it; without it the chip resets ~1×/s with
> `rst:0x12 (SUPER_WDT_RST)`.

---

## Timing

In Direct Boot the CPU runs at the ROM default clock and code executes XIP from
flash, so the delay loop measures **~200 ns per iteration**:

| `DELAY_CYCLES` | Half-period | Full period |
|---|---|---|
| `40 000 000` | 8.0 s | 16 s |
| `2 500 000` (current) | 0.5 s | **1.0 s** (≈1 Hz) |

For deterministic timing, configure the CPU PLL (160 MHz) explicitly — not done
here to keep the example minimal.

---

## Troubleshooting

- **`esptool: No serial data received`** — the board did not enter download
  mode. Retry (the CH340 bridge sometimes misses the auto-reset), or enter it
  manually: **hold BOOT → tap RST → release BOOT**. The native USB-Serial-JTAG
  port (a separate COM) is an alternative.
- **No blink / reset loop** — verify `blink.bin` starts with `1d 04 db ae` ×2
  and that flash was written at `0x0`. Check the UART for the reset reason
  (`rst:0x..`).
- **Verify the image:**
  ```sh
  mingw32-make dis        # _start must be at 0x42000008
  ```
