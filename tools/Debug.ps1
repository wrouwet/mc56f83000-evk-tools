<#
.SYNOPSIS
    Runs a TCL script against CodeWarrior's Debugger Shell (cwide.exe /
    cwidec.exe) — confirmed real executables, no Eclipse GUI required.

.PARAMETER Script
    Path to a .tcl script under debug/ (e.g. debug\session.tcl).

.PARAMETER Config
    Build configuration whose output to debug (see tools/Build.ps1).

.PARAMETER ElfPath
    Override auto-discovery of the built .elf under project/.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Script,
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

if (-not $CWIDE -or -not (Test-Path $CWIDE)) {
    Write-Error "CWIDE (cwide.exe/cwidec.exe) is not set to a valid path in config/toolchain.ps1 (got: '$CWIDE'). See docs/SETUP.md step 4."
    exit 1
}

if (-not (Test-Path $Script)) {
    Write-Error "Script not found: $Script"
    exit 1
}

if (-not $ElfPath) {
    $projectDir = Join-Path $root 'project'
    $elf = Get-ChildItem -Path $projectDir -Recurse -Filter '*.elf' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match [regex]::Escape($Config) } |
        Select-Object -First 1
    if (-not $elf) { $elf = Get-ChildItem -Path $projectDir -Recurse -Filter '*.elf' -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if (-not $elf) { Write-Error "No .elf found under project/ — run tools/Build.ps1 first."; exit 1 }
    $ElfPath = $elf.FullName
}

Write-Host "Launching Debugger Shell ($CWIDE) with $Script against $ElfPath..." -ForegroundColor Cyan

# cwide.exe/cwidec.exe are confirmed (per the same NXP CLI reference doc
# as ecd.exe) to run a Debugger Shell TCL script headlessly. The exact
# switch to point them at a startup script is NOT yet confirmed from that
# doc — it references a separate mcuoneclipse.com walkthrough for the
# scripting mechanics. Confirm the invocation shape against
# {CW install}\Help\ once installed and adjust here; this is the
# best-documented placeholder shape (Eclipse debug launches commonly take
# -Dcw.script=<path>).
& $CWIDE "-Dcw.script=$Script" $ElfPath
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Warning "Debugger Shell exited with code $exitCode."
}
