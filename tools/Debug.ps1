<#
.SYNOPSIS
    Launches CodeWarrior's Debugger Shell against the MC56F83000-EVK and
    runs a TCL script against it — no Eclipse GUI required.

.PARAMETER Script
    Path to a .tcl script under debug/ (e.g. debug\session.tcl).

.PARAMETER ElfPath
    Override the default build/app.elf.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Script,
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

if (-not $DEBUG -or -not (Test-Path $DEBUG)) {
    Write-Error "DEBUG tool path is not set/valid in config/toolchain.ps1 (got: '$DEBUG'). See docs/SETUP.md step 4."
    exit 1
}

if (-not (Test-Path $Script)) {
    Write-Error "Script not found: $Script"
    exit 1
}

if (-not $ElfPath) { $ElfPath = Join-Path $root 'build\app.elf' }
if (-not (Test-Path $ElfPath)) {
    Write-Error "$ElfPath not found — run tools/Build.ps1 first."
    exit 1
}

Write-Host "Launching Debugger Shell with $Script against $ElfPath..." -ForegroundColor Cyan

# NOTE: exact switch for pointing the Debugger Shell at a startup TCL
# script is version-dependent (commonly -Dcw.script=<path> for CW10+
# Eclipse-based debug launches). Confirm against your version's Debugger
# Manual (see docs/SETUP.md step 7) and adjust once.
& $DEBUG "-Dcw.script=$Script" $ElfPath
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Warning "Debugger Shell exited with code $exitCode."
}
