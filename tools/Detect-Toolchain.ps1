<#
.SYNOPSIS
    One-time "configure" step (like autotools' ./configure): scans a
    CodeWarrior for DSC install tree for the real executables this
    repo's Makefile drives directly, and writes their paths - plus the
    MCUXpresso SDK root - to config/toolchain.mk. Everything after this
    is `make build` / `make flash` / `make clean`; PowerShell isn't
    needed again.

.DESCRIPTION
    The Makefile calls mwcc56800e.exe/mwasm56800e.exe/mwld56800e.exe/
    fflash.exe directly - no CodeWarrior Eclipse project format, no
    ecd.exe, no IDE. (See docs/ARCHITECTURE.md for why: the Eclipse
    project format's PARENT-5-PROJECT_LOC-style relative paths only
    resolve correctly at the SDK's own original folder depth, which
    broke as soon as the project was copied into this repo.) This
    script still locates cwide.exe/cwidec.exe for reference - it's
    needed once, unavoidably, for the JM60 on-board-probe firmware
    update (docs/SETUP.md step 6) - but the Makefile never calls it.

.PARAMETER CwRoot
    Root of your CodeWarrior for DSC installation, e.g.
    "C:\Freescale\CW MCU v11.2".

.PARAMETER SdkRoot
    Root of your MCUXpresso SDK checkout for this board, e.g.
    "C:\Users\you\SDK_26_06_00_MC56F83000-EVK". Not scanned for - you
    know where you put it.

.EXAMPLE
    .\tools\Detect-Toolchain.ps1 -CwRoot "C:\Freescale\CW MCU v11.2" -SdkRoot "C:\Users\you\SDK_26_06_00_MC56F83000-EVK"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$CwRoot,

    [Parameter(Mandatory = $true)]
    [string]$SdkRoot
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $CwRoot)) {
    Write-Error "CwRoot not found: $CwRoot"
    exit 1
}
if (-not (Test-Path $SdkRoot)) {
    Write-Error "SdkRoot not found: $SdkRoot"
    exit 1
}

Write-Host "Scanning $CwRoot for CodeWarrior CLI tools..." -ForegroundColor Cyan

$patterns = [ordered]@{
    Compiler         = @('mwcc56800e.exe')
    Assembler        = @('mwasm56800e.exe')
    Linker           = @('mwld56800e.exe')
    FlashProgrammer  = @('fflash.exe')
    Make             = @('make.exe')
    DebuggerShell    = @('cwidec.exe', 'cwide.exe')
}

$found = [ordered]@{}
$ambiguous = @()

foreach ($role in $patterns.Keys) {
    # Try each pattern in priority order and stop at the first one that
    # matches anything, rather than merging all patterns and picking
    # arbitrarily.
    $matches = @()
    foreach ($pat in $patterns[$role]) {
        $patMatches = @(Get-ChildItem -Path $CwRoot -Recurse -File -Filter $pat -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName -Unique | Sort-Object Length)
        if ($patMatches.Count -gt 0) { $matches = $patMatches; break }
    }
    # @(...) above forces an array even when exactly one match is found -
    # without it, PowerShell collapses a single-element pipeline to a bare
    # string, and $matches[0] below would index into that string's
    # *characters* instead of the array (silently truncating a path to its
    # first letter). Sort-Object Length prefers the shallower of any
    # same-pattern duplicates (e.g. gnu\bin\make.exe over a copy nested
    # under eclipse\plugins\...).

    if ($matches.Count -eq 0) {
        Write-Host "  [MISSING] $role - no match for $($patterns[$role] -join ', '). See docs/SETUP.md step 4." -ForegroundColor Yellow
        $found[$role] = $null
    }
    elseif ($matches.Count -eq 1) {
        Write-Host "  [OK]      $role -> $($matches[0])" -ForegroundColor Green
        $found[$role] = $matches[0]
    }
    else {
        Write-Host "  [MULTIPLE] $role - found $($matches.Count) candidates, picking first; edit config/toolchain.mk if wrong:" -ForegroundColor Yellow
        $matches | ForEach-Object { Write-Host "             $_" }
        $found[$role] = $matches[0]
        $ambiguous += $role
    }
}

# Make handles forward slashes fine on Windows, and it sidesteps having
# to escape backslashes in a Makefile - GNU Make variable files read a
# lot more like their Linux counterparts this way.
function ToMakePath([string]$p) {
    if ($null -eq $p) { return $p }
    return $p -replace '\\', '/'
}

# P&E's DSC GDI driver. fflash.exe MUST be passed this explicitly via
# -gdi= or it silently fails to reach this board's OSJTAG probe (bare
# non-zero exit, no diagnostics at all) - see the Makefile's flash target.
# Deliberately derived from fflash.exe's own directory rather than
# searched for: a CodeWarrior install carries more than one copy of this
# DLL (there's another under MCU\bin\plugins\support\), and the one that
# belongs with the flash programmer is the one sitting next to it.
$gdi = $null
if ($found.FlashProgrammer) {
    $gdiCandidate = Join-Path (Split-Path $found.FlashProgrammer -Parent) 'DSC\gdi\dsc_pne_gdi.dll'
    if (Test-Path $gdiCandidate) {
        $gdi = $gdiCandidate
        Write-Host "  [OK]      Gdi -> $gdi" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] Gdi - expected dsc_pne_gdi.dll next to fflash.exe at $gdiCandidate. 'make flash' will fail silently without it - see docs/SETUP.md step 6." -ForegroundColor Yellow
    }
}

# GNU Make on Windows defaults to cmd.exe for recipe lines, which has no
# mkdir -p / rm -rf. Git for Windows ships a full POSIX toolset, so point
# Make's SHELL at its bash and the Makefile's recipes stay ordinary
# POSIX shell - no cmd-specific escaping anywhere.
Write-Host ""
Write-Host "Locating a POSIX shell for GNU Make..." -ForegroundColor Cyan
$bash = $null
$bashCandidates = @(
    (Get-Command bash.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1)
    "$env:ProgramFiles\Git\bin\bash.exe"
    "${env:ProgramFiles(x86)}\Git\bin\bash.exe"
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
)
foreach ($cand in $bashCandidates) {
    if ($cand -and (Test-Path $cand)) { $bash = $cand; break }
}
if ($bash) {
    Write-Host "  [OK]      Shell -> $bash" -ForegroundColor Green
} else {
    Write-Host "  [MISSING] Shell - no bash.exe found. Install Git for Windows (it ships one), then re-run this script. See docs/SETUP.md step 4." -ForegroundColor Yellow
}

$configDir = Join-Path $PSScriptRoot '..\config'
New-Item -ItemType Directory -Force -Path $configDir | Out-Null
$configPath = Join-Path $configDir 'toolchain.mk'

$lines = @(
    "# Auto-generated by tools/Detect-Toolchain.ps1 on $(Get-Date -Format o)"
    "# Machine-specific - not committed to git (see .gitignore)."
    ""
    "SHELL    := $(ToMakePath $bash)"
    "CW_ROOT  := $(ToMakePath $CwRoot)"
    "SDK_ROOT := $(ToMakePath $SdkRoot)"
    "CC       := $(ToMakePath $found.Compiler)"
    "AS       := $(ToMakePath $found.Assembler)"
    "LD       := $(ToMakePath $found.Linker)"
    "FFLASH   := $(ToMakePath $found.FlashProgrammer)"
    "GDI      := $(ToMakePath $gdi)"
    "CWIDE    := $(ToMakePath $found.DebuggerShell)"
)
# Windows PowerShell 5.1's -Encoding utf8 always emits a BOM, and GNU
# Make reports "missing separator" on the BOM'd first line. Write bytes
# directly with a BOM-less UTF8 encoder instead.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($configPath, ($lines -join "`r`n") + "`r`n", $utf8NoBom)

Write-Host ""
Write-Host "Wrote $configPath" -ForegroundColor Cyan
Write-Host "Next: make build   (see README.md / docs/SETUP.md)" -ForegroundColor Cyan

if (-not $found.Compiler -or -not $found.Assembler -or -not $found.Linker -or -not $found.FlashProgrammer -or -not $gdi) {
    Write-Host "One or more tools the Makefile actually needs (Compiler/Assembler/Linker/FlashProgrammer/Gdi) were not found - fill them in by hand in config/toolchain.mk (see docs/SETUP.md step 4)." -ForegroundColor Yellow
}
if ($ambiguous.Count -gt 0) {
    Write-Host "Ambiguous matches for: $($ambiguous -join ', ') - verify config/toolchain.mk picked the right one (e.g. multiple CodeWarrior versions installed)." -ForegroundColor Yellow
}
if (-not $bash) {
    Write-Host "No POSIX shell was recorded - `make` will fall back to cmd.exe and the Makefile's recipes will fail. Install Git for Windows and re-run." -ForegroundColor Yellow
}
if (-not $found.Make) {
    Write-Host "make.exe wasn't found under $CwRoot - you'll need GNU Make on PATH some other way (it usually lives at '{CW install}\gnu\bin\make.exe' - add that to PATH, or install Git for Windows / GnuWin32 make)." -ForegroundColor Yellow
}
