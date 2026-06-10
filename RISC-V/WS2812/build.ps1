# build.ps1 — Bare-metal збірка WS2812 для ESP32-C3
# Використання: .\build.ps1 [-d для дизасемблера]

$toolchain = "$env:USERPROFILE\.espressif\tools\riscv32-esp-elf\esp-14.2.0_20251107\riscv32-esp-elf\bin"
$python    = "$env:USERPROFILE\.espressif\python_env\idf5.5_py3.12_env\Scripts\python.exe"
$idf       = "$env:USERPROFILE\.platformio\packages\framework-espidf"

$cc      = "$toolchain\riscv32-esp-elf-gcc.exe"
$objdump = "$toolchain\riscv32-esp-elf-objdump.exe"

$arch  = @("-march=rv32imc_zicsr", "-mabi=ilp32")
$flags = @("-Os", "-nostdlib", "-ffreestanding", "-Wall", "-Wl,-Map=ws2812.map")

# Include шляхи: наш порожній stdint.h йде ПЕРШИМ
$includes = @(
    "-I.\include",                               # порожній stdint.h (блокує системний)
    "-I$idf\components\soc\esp32c3\include",     # soc/soc.h
    "-I$idf\components\soc\esp32c3\register",    # soc/timer_group_reg.h, rtc_cntl_reg.h
    "-I$idf\components\esp_common\include",      # esp_bit_defs.h (потрібен soc.h)
    "-I$idf\components\soc\include"              # загальні soc хедери
)

$srcs = @("src\startup.S", "src\ws2812.S")

Write-Output "[ CC ] $srcs"
& $cc @arch @flags @includes -T link.ld -o ws2812.elf @srcs
if ($LASTEXITCODE -ne 0) { Write-Error "Compile FAILED"; exit 1 }

Write-Output "[ BIN ] elf2image"
& $python -m esptool --chip esp32c3 elf2image `
    --flash_mode dio --flash_freq 80m --flash_size 4MB `
    -o ws2812.bin ws2812.elf
if ($LASTEXITCODE -ne 0) { Write-Error "elf2image FAILED"; exit 1 }

$size = (Get-Item ws2812.bin).Length
Write-Output "[ OK ] ws2812.bin  ($size bytes)"

if ($args -contains "-d") {
    & $objdump -d -M no-aliases ws2812.elf
}
