<#
.SYNOPSIS
    Builds the CodeWarrior Eclipse project in project/ headlessly via
    ecd.exe - confirmed syntax, no GUI required.

.PARAMETER Config
    Build configuration name. NXP's MC56F83000-EVK SDK examples use
    "flash_ldm_lpm_debug" and "flash_ldm_lpm_release".

.PARAMETER Clean
    Pass -cleanBuild to ecd.exe (removes previous build output first).

.PARAMETER Workspace
    Eclipse workspace directory ecd.exe uses via -data. Defaults to
    build\workspace under this repo; created if missing.
#>
param(
    [string]$Config = 'flash_ldm_lpm_debug',
    [switch]$Clean,
    [string]$Workspace
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$configPath = Join-Path $root 'config\toolchain.ps1'

if (-not (Test-Path $configPath)) {
    Write-Error "config/toolchain.ps1 not found. Run tools/Detect-Toolchain.ps1 first (see README quick start)."
    exit 1
}
. $configPath

if (-not $ECD -or -not (Test-Path $ECD)) {
    Write-Error "ECD (ecd.exe) is not set to a valid path in config/toolchain.ps1 (got: '$ECD'). See docs/SETUP.md step 4."
    exit 1
}

$projectRoot = Join-Path $root 'project'
# SDK example projects put .cproject in a codewarrior\ subfolder alongside
# the source files (which it references via relative paths like
# ..\board.c) rather than at the example's root - so search for it rather
# than assuming a fixed depth.
$cprojectFile = Get-ChildItem -Path $projectRoot -Recurse -Filter '.cproject' -Force -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $cprojectFile) {
    Write-Error "No .cproject found anywhere under project/. project/ must contain a real CodeWarrior Eclipse project - see project/PLACEHOLDER.md."
    exit 1
}
$projectDir = $cprojectFile.DirectoryName

if (-not $Workspace) { $Workspace = Join-Path $root 'build\workspace' }
New-Item -ItemType Directory -Force -Path $Workspace | Out-Null

# Confirmed syntax (NXP community doc "CodeWarrior 10 Command Line
# Interface - usage and examples", By Jennie Zhang):
#   ecd.exe build -data <workspace> -project <path> [-config <name>] [-cleanBuild]
$ecdArgs = @('build', '-data', $Workspace, '-project', $projectDir, '-config', $Config)
if ($Clean) { $ecdArgs += '-cleanBuild' }

Write-Host "ecd.exe $($ecdArgs -join ' ')" -ForegroundColor Cyan
& $ECD @ecdArgs
if ($LASTEXITCODE -ne 0) { Write-Error "Build failed (exit $LASTEXITCODE)"; exit $LASTEXITCODE }

$elf = Get-ChildItem -Path $projectDir -Recurse -Filter '*.elf' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match [regex]::Escape($Config) } |
    Select-Object -First 1
if (-not $elf) {
    $elf = Get-ChildItem -Path $projectDir -Recurse -Filter '*.elf' -ErrorAction SilentlyContinue | Select-Object -First 1
}

if ($elf) {
    Write-Host "Build OK -> $($elf.FullName)" -ForegroundColor Green
} else {
    Write-Warning "Build reported success but no .elf was found under project/ - check ecd.exe output above."
}
