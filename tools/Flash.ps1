<#
.SYNOPSIS
    Programs build/app.elf onto the MC56F83000-EVK over its on-board OSBDM
    interface using CodeWarrior's Flash Programmer, from the command line.

.PARAMETER Run
    Reset and let the target run after programming (instead of leaving it
    halted for a debug session).

.PARAMETER ElfPath
    Override the default build/app.elf.
#>
param(
    [switch]$Run,
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
    Write-Error "FLASH tool path is not set/valid in config/toolchain.ps1 (got: '$FLASH'). See docs/SETUP.md step 4."
    exit 1
}

if (-not $ElfPath) { $ElfPath = Join-Path $root 'build\app.elf' }
if (-not (Test-Path $ElfPath)) {
    Write-Error "$ElfPath not found — run tools/Build.ps1 first."
    exit 1
}

$flashCfg = Join-Path $root 'flash\flash.cfg'
if (-not (Test-Path $flashCfg)) {
    Write-Error "flash/flash.cfg not found. Copy a device-matched template from your CodeWarrior install — see flash/flash.cfg.example."
    exit 1
}

Write-Host "Flashing $ElfPath over OSBDM..." -ForegroundColor Cyan

# Confirmed syntax (Freescale "56800E Flash Programmer User's Guide", Rev 0,
# 09/2005): fflash <flash.cfg> <image file(s)> [options]
#   -USB          force the USB (OSBDM) interface — this board's path
#   -erase=<all|unit|page>   defaults to "unit" if omitted
#   -jtagclk=<kHz>           JTAG clock, default 800
#   -l<logfile>              redirect messages to a log file
# NOT yet confirmed: a dedicated run/reset-after-program flag. If -Run is
# requested and fflash has no such flag, "running" may instead need a
# separate reset triggered via tools/Debug.ps1 (see debug/run.tcl) — verify
# against the manual shipped in your install and adjust here once.
$flashArgs = @($flashCfg, $ElfPath, '-USB')
if ($Run) {
    Write-Warning "No confirmed 'run after flash' flag for fflash yet — verify against your install's Flash Programmer manual. Falling back to a separate reset via tools/Debug.ps1 -Script debug/run.tcl if this doesn't already leave the target running."
}

& $FLASH @flashArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flash failed (exit $LASTEXITCODE). Check the board is enumerated in Device Manager and no other CodeWarrior/P&E process has the OSBDM interface open."
    exit $LASTEXITCODE
}

Write-Host "Flash OK" -ForegroundColor Green
if ($Run) { Write-Host "Target reset and running." -ForegroundColor Green }
else { Write-Host "Target halted — use tools/Debug.ps1 to attach, or re-run with -Run." -ForegroundColor Yellow }
