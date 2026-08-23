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

Write-Host "Flashing $ElfPath over OSBDM..." -ForegroundColor Cyan

# NOTE: exact CLI switches for the 56800E Flash Programmer are
# version-dependent. Confirm against your install's docs (see
# docs/SETUP.md) and adjust this invocation once — after that it's fixed.
# Typical shape: FlashProgrammer.exe <image> -device <part> -interface OSBDM [-run]
$flashArgs = @($ElfPath)
if ($Run) { $flashArgs += '-run' }

& $FLASH @flashArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flash failed (exit $LASTEXITCODE). Check the board is enumerated in Device Manager and no other CodeWarrior/P&E process has the OSBDM interface open."
    exit $LASTEXITCODE
}

Write-Host "Flash OK" -ForegroundColor Green
if ($Run) { Write-Host "Target reset and running." -ForegroundColor Green }
else { Write-Host "Target halted — use tools/Debug.ps1 to attach, or re-run with -Run." -ForegroundColor Yellow }
