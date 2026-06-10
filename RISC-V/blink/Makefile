# Makefile — blink bare-metal RISC-V (ESP32-C3, 160 MHz)
#
# Commands (use mingw32-make on Windows):
#   mingw32-make              — build
#   mingw32-make flash PORT=COM5
#   mingw32-make dis          — disassemble
#   mingw32-make clean
#
# Requires: GNU make, bootloader.bin and partition-table.bin
# (copy from ../WS2812/ or generate via ESP-IDF)

USER_HOME := $(subst \,/,$(USERPROFILE))
ESPRESSIF := $(USER_HOME)/.espressif
TOOLCHAIN := $(ESPRESSIF)/tools/riscv32-esp-elf/esp-14.2.0_20251107/riscv32-esp-elf/bin
PYTHON    := $(ESPRESSIF)/python_env/idf5.5_py3.12_env/Scripts/python.exe
IDF       := $(USER_HOME)/.platformio/packages/framework-espidf

CC        := $(TOOLCHAIN)/riscv32-esp-elf-gcc.exe
OBJDUMP   := $(TOOLCHAIN)/riscv32-esp-elf-objdump.exe
OBJCOPY   := $(TOOLCHAIN)/riscv32-esp-elf-objcopy.exe

ARCH      := -march=rv32imc_zicsr -mabi=ilp32
# -g adds DWARF debug info to the .elf (source-level stepping/breakpoints in
# the debugger).  It does not affect blink.bin — objcopy copies only code.
CFLAGS    := -Os -g -nostdlib -ffreestanding -Wall
LDFLAGS   := -T link.ld

INCLUDES  := \
    -I./include \
    -I$(IDF)/components/soc/esp32c3/include \
    -I$(IDF)/components/soc/esp32c3/register \
    -I$(IDF)/components/esp_common/include \
    -I$(IDF)/components/soc/include

SRCS := src/startup.S src/blink.S src/uart.S
PORT ?= COM3

.PHONY: all flash erase dis clean

all: blink.bin

blink.elf: $(SRCS)
	$(CC) $(ARCH) $(CFLAGS) $(INCLUDES) $(LDFLAGS) -Wl,-Map=blink.map -o $@ $^
	@echo "[ELF] $@"

# Direct boot: produce a RAW flash image (no ESP image header, no elf2image).
# The two magic words at the very start trigger the ROM's direct-boot path.
blink.bin: blink.elf
	$(OBJCOPY) -O binary $< $@
	@echo "[BIN] $@"

# Flash the raw image at 0x0, replacing any second-stage bootloader.
# No partition table / no app partition needed in direct boot.
flash: blink.bin
	$(PYTHON) -m esptool --chip esp32c3 -p $(PORT) \
		--before default_reset --after hard_reset write_flash \
		0x0 blink.bin

# Erase the whole flash (clears the old ESP-IDF bootloader + partitions).
erase:
	$(PYTHON) -m esptool --chip esp32c3 -p $(PORT) erase_flash

dis: blink.elf
	$(OBJDUMP) -d -M no-aliases $<

clean:
	-rm -f *.elf *.bin *.map
