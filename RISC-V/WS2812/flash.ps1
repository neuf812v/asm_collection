# flash.ps1 — Прошивка bare-metal бінарника на ESP32-C3
# Використання: .\flash.ps1 [-Port COM3] [-AppOnly]

param(
    [string]$Port    = "COM3",
    [switch]$AppOnly           # тільки ws2812.bin (без bootloader/partition)
)

$python = "$env:USERPROFILE\.espressif\python_env\idf5.5_py3.12_env\Scripts\python.exe"

if ($AppOnly) {
    Write-Output "[ FLASH ] Тільки app → $Port"
    & $python -m esptool --chip esp32c3 -p $Port -b 460800 `
        --before default_reset --after hard_reset `
        write_flash 0x10000 ws2812.bin
} else {
    Write-Output "[ FLASH ] Bootloader + partition + app → $Port"
    & $python -m esptool --chip esp32c3 -p $Port -b 460800 `
        --before default_reset --after hard_reset `
        write_flash `
            0x00000 bootloader.bin `
            0x08000 partition-table.bin `
            0x10000 ws2812.bin
}
