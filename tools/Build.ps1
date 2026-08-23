<#
.SYNOPSIS
    Compiles, assembles, and links src/*.c (and src/*.asm, if any) into
    build/app.elf using the CodeWarrior 56800E command-line tools.

.PARAMETER Clean
    Remove build/ before building.
#>
param(
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$configPath = Join-Path $root 'config\toolchain.ps1'

if (-not (Test-Path $configPath)) {
    Write-Error "config/toolchain.ps1 not found. Run tools/Detect-Toolchain.ps1 first (see README quick start)."
    exit 1
}
. $configPath

foreach ($tool in @('CC', 'ASM', 'LD')) {
    $path = (Get-Variable $tool).Value
    if (-not $path -or -not (Test-Path $path)) {
        Write-Error "$tool is not set to a valid path in config/toolchain.ps1 (got: '$path'). See docs/SETUP.md step 4."
        exit 1
    }
}

$buildDir = Join-Path $root 'build'
if ($Clean -and (Test-Path $buildDir)) {
    Remove-Item $buildDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

$srcDir = Join-Path $root 'src'
$cSources = Get-ChildItem -Path $srcDir -Filter '*.c' -File -ErrorAction SilentlyContinue
$asmSources = Get-ChildItem -Path $srcDir -Filter '*.asm' -File -ErrorAction SilentlyContinue

if (-not $cSources -and -not $asmSources) {
    Write-Error "No sources found in src/. See README 'Important note on src/ and linker/'."
    exit 1
}

$objects = @()

foreach ($src in $cSources) {
    $obj = Join-Path $buildDir "$($src.BaseName).o"
    Write-Host "CC   $($src.Name)" -ForegroundColor Cyan
    & $CC $src.FullName -o $obj
    if ($LASTEXITCODE -ne 0) { Write-Error "Compile failed: $($src.Name)"; exit $LASTEXITCODE }
    $objects += $obj
}

foreach ($src in $asmSources) {
    $obj = Join-Path $buildDir "$($src.BaseName).o"
    Write-Host "ASM  $($src.Name)" -ForegroundColor Cyan
    & $ASM $src.FullName -o $obj
    if ($LASTEXITCODE -ne 0) { Write-Error "Assemble failed: $($src.Name)"; exit $LASTEXITCODE }
    $objects += $obj
}

$linkerCmd = Get-ChildItem -Path (Join-Path $root 'linker') -Filter '*.cmd' -File -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $linkerCmd) {
    Write-Error "No linker .cmd file found in linker/. Copy one from your CodeWarrior example project — see README step 5."
    exit 1
}

$outElf = Join-Path $buildDir 'app.elf'
Write-Host "LD   -> build/app.elf (using $($linkerCmd.Name))" -ForegroundColor Cyan
& $LD $objects -o $outElf -m $linkerCmd.FullName
if ($LASTEXITCODE -ne 0) { Write-Error "Link failed"; exit $LASTEXITCODE }

Write-Host "Build OK -> $outElf" -ForegroundColor Green
Write-Host "NOTE: exact flags above (-o, -m) are CodeWarrior-version-dependent placeholders." -ForegroundColor Yellow
Write-Host "      Verify against 56800x_Build_Tools_Reference.pdf and adjust this script once, then it's fixed for good." -ForegroundColor Yellow
