# Makefile — WS2812 bare-metal RISC-V (ESP32-C3, 160 MHz)
#
# Commands (use mingw32-make on Windows):
#   mingw32-make bitbang          — build bit-bang variant (default)
#   mingw32-make rmt              — build RMT variant
#   mingw32-make spi              — build SPI/DMA variant
#   mingw32-make dedgpio          — build Dedicated GPIO variant
#   mingw32-make flash-bitbang PORT=COM5
#   mingw32-make dis-bitbang      — disassemble
#   mingw32-make clean

USER_HOME := $(subst \,/,$(USERPROFILE))
ESPRESSIF := $(USER_HOME)/.espressif
TOOLCHAIN := $(ESPRESSIF)/tools/riscv32-esp-elf/esp-14.2.0_20251107/riscv32-esp-elf/bin
PYTHON    := $(ESPRESSIF)/python_env/idf5.5_py3.12_env/Scripts/python.exe
IDF       := $(USER_HOME)/.platformio/packages/framework-espidf

CC        := $(TOOLCHAIN)/riscv32-esp-elf-gcc.exe
OBJDUMP   := $(TOOLCHAIN)/riscv32-esp-elf-objdump.exe

ARCH      := -march=rv32imc_zicsr -mabi=ilp32
CFLAGS    := -Os -nostdlib -ffreestanding -Wall
LDFLAGS   := -T link.ld

INCLUDES  := \
    -I./include \
    -I$(IDF)/components/soc/esp32c3/include \
    -I$(IDF)/components/soc/esp32c3/register \
    -I$(IDF)/components/esp_common/include \
    -I$(IDF)/components/soc/include

STARTUP   := src/startup.S
PORT      ?= COM3
VARIANTS  := bitbang rmt spi dedgpio

.PHONY: all clean $(VARIANTS) $(addprefix flash-,$(VARIANTS)) $(addprefix dis-,$(VARIANTS))

all: bitbang

# --- Build rules for each variant ---
define WS2812_RULES
$(1): ws2812_$(1).bin

ws2812_$(1).elf: $(STARTUP) src/ws2812_$(1).S
	$(CC) $(ARCH) $(CFLAGS) $(INCLUDES) $(LDFLAGS) -Wl,-Map=ws2812_$(1).map -o $$@ $$^
	@echo "[ELF] $$@"

ws2812_$(1).bin: ws2812_$(1).elf
	$(PYTHON) -m esptool --chip esp32c3 elf2image \
		--flash_mode dio --flash_freq 80m --flash_size 4MB -o $$@ $$<
	@echo "[BIN] $$@"

flash-$(1): ws2812_$(1).bin
	$(PYTHON) -m esptool --chip esp32c3 -p $(PORT) \
		--before default_reset --after hard_reset write_flash \
		0x0     bootloader.bin \
		0x8000  partition-table.bin \
		0x10000 ws2812_$(1).bin

dis-$(1): ws2812_$(1).elf
	$(OBJDUMP) -d -M no-aliases $$<
endef

$(foreach v,$(VARIANTS),$(eval $(call WS2812_RULES,$(v))))

clean:
	-rm -f *.elf *.bin *.map
