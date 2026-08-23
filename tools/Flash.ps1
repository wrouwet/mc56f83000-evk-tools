<#
.SYNOPSIS
    Programs the built .elf onto the MC56F83000-EVK over its on-board
    OSJTAG interface (via USB port J8) using the confirmed fflash.exe.

.PARAMETER Config
    Build configuration whose output to flash (see tools/Build.ps1).

.PARAMETER ElfPath
    Override auto-discovery of the built .elf under project/.
#>
param(
    [string]$Config = 'flash_ldm_lpm_debug',
    [string]$ElfPath
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$configPath = Join-Path $root 'config\toolchain.ps1'

if (-not (Test-Path $configPath)) {
    Write-Error "config/toolchain.ps1 not found. Run tools/Detect-Toolchain.ps1 first."
    exit 1
}
. $configPath

if (-not $FLASH -or -not (Test-Path $FLASH)) {
    Write-Error "FLASH (fflash.exe) is not set to a valid path in config/toolchain.ps1 (got: '$FLASH'). See docs/SETUP.md step 4."
    exit 1
}

if (-not $ElfPath) {
    $projectDir = Join-Path $root 'project'
    $elf = Get-ChildItem -Path $projectDir -Recurse -Filter '*.elf' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match [regex]::Escape($Config) } |
        Select-Object -First 1
    if (-not $elf) { $elf = Get-ChildItem -Path $projectDir -Recurse -Filter '*.elf' -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if (-not $elf) { Write-Error "No .elf found under project/ - run tools/Build.ps1 first."; exit 1 }
    $ElfPath = $elf.FullName
}
if (-not (Test-Path $ElfPath)) {
    Write-Error "$ElfPath not found."
    exit 1
}

$flashCfg = Join-Path $root 'flash\flash.cfg'
if (-not (Test-Path $flashCfg)) {
    Write-Error "flash/flash.cfg not found. Copy a device-matched template - see flash/flash.cfg.example."
    exit 1
}

Write-Host "Flashing $ElfPath over OSJTAG (board's on-board USB debug port, J8)..." -ForegroundColor Cyan

# Confirmed syntax (Freescale "56800E Flash Programmer User's Guide", Rev
# 0, 09/2005): fflash <flash.cfg> <image file(s)> [options]
#   -USB   force the USB interface (this board's on-board OSJTAG path)
# NOT yet confirmed: a dedicated run/reset-after-program flag - verify
# against the manual shipped in your install (docs/SETUP.md step 4).
& $FLASH $flashCfg $ElfPath '-USB'
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flash failed (exit $LASTEXITCODE). Check the board enumerates in Device Manager and no other CodeWarrior/P&E process has the debug interface open."
    exit $LASTEXITCODE
}

Write-Host "Flash OK" -ForegroundColor Green
