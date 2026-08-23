# MC56F83000-EVK CLI Toolchain

A local, command-line-only build / flash / debug environment for the NXP
**MC56F83000-EVK** evaluation board (MC56F83789, 56800E DSC core), driven
entirely from PowerShell — no IDE window required for day-to-day work.

## Read this first: what this repo is and isn't

The 56800E core is a proprietary hybrid DSP/MCU architecture. There is
**no upstream GCC or LLVM backend** for it. The only realistic toolchain
is **NXP CodeWarrior for DSC v11.2 + SP1** (Eclipse-based, free to
download and register but closed-source) — confirmed as what NXP's
current MCUXpresso SDK docs for this exact board require. Note: this is
a different product from "CodeWarrior for MCUs v11.1" — v11.1 (even with
Update 3) cannot build current SDK releases for this board; see
docs/SETUP.md step 1 for why.

This repo does **not** bundle CodeWarrior — it bundles scripts that drive
its real, documented command-line entry points instead of the Eclipse
GUI. You still need to install it once; everything after that is
scriptable.

- ✅ Fully scriptable, IDE-free build → flash → run → debug loop, built on
  **confirmed, sourced** executable names and syntax (see
  [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for citations) — not
  guesses
- ✅ Everything here (Makefile, PowerShell scripts, TCL debug scripts) is
  yours, MIT-licensed, and lives in this repo
- ❌ CodeWarrior itself, and the MCUXpresso SDK example project you'll
  seed `project/` from, are NXP's — installed separately, referenced by
  path, not redistributed here
- ⚠️ A couple of specifics are still unverified pending an actual install
  (flagged inline in the scripts and in "What's confirmed" below) — this
  repo is honest about the difference between the two

## Prerequisites

1. **NXP CodeWarrior for DSC v11.2 + SP1** — download from NXP's
   "CodeWarrior for 56800 Digital Signal Controller v11.2" product page
   (product code `CW-DSC`) — **not** the "CodeWarrior for MCUs v11.1"
   page, which is a different, older product that can't build current
   SDK releases for this board. Free, requires a (free) NXP account. See
   [docs/SETUP.md](docs/SETUP.md) step 1.
2. **MCUXpresso SDK for MC56F83000-EVK** (e.g. `SDK_2.7.1_MC56F83000-EVK`)
   — separate download, provides real example projects with correct
   linker files, device headers, and startup code for your exact chip.
3. Windows 10/11 with PowerShell (you already have this).
4. The MC56F83000-EVK board, connected via its **on-board OSJTAG** USB
   port (labeled **J8**) — this is the confirmed default debug interface
   for this board, not the OSBDM/P&E-Multilink path used by some older
   56800E boards. An external P&E U-MultiLink is supported as an
   alternative if you have one.
5. Optional: `make` if you prefer the `ecd.exe -generateMakefiles` +
   `make` path over `ecd.exe build` directly — not required.

## Quick start

```powershell
# 1. One-time: point this repo at your CodeWarrior install and let it
#    find the real ecd.exe / cwide.exe / fflash.exe executables.
.\tools\Detect-Toolchain.ps1 -CwRoot "C:\Freescale\CW MCU v11.2"

# 2. Build (see project/PLACEHOLDER.md — project/ must hold a real
#    CodeWarrior Eclipse project copied from the SDK first)
.\tools\Build.ps1

# 3. Flash over OSJTAG
.\tools\Flash.ps1

# 4. Debug (scripted TCL session against CodeWarrior's Debugger Shell)
.\tools\Debug.ps1 -Script debug\session.tcl
```

`make build`, `make flash`, `make debug`, `make clean` are thin wrappers
around the same scripts.

## Layout

```
config/     toolchain.ps1 — machine-specific tool paths (generated, gitignored)
tools/      Detect-Toolchain.ps1, Build.ps1, Flash.ps1, Debug.ps1
debug/      TCL scripts for CodeWarrior's Debugger Shell (cwide.exe/cwidec.exe)
flash/      flash.cfg — device/interface config for fflash.exe (see note below)
project/    the actual CodeWarrior Eclipse project — see project/PLACEHOLDER.md
docs/       SETUP.md (install walkthrough), ARCHITECTURE.md (why it's built this way, with citations)
```

## What's confirmed vs. still unverified

**Confirmed, with sources** (see docs/ARCHITECTURE.md):

- CodeWarrior for DSC **v11.2 + SP1** is the toolchain current
  MCUXpresso SDK releases actually require for this board — confirmed
  from NXP's own current SDK build docs, and the hard way: v11.1 + Update
  3 was tried first and provably cannot build this SDK release (see
  docs/SETUP.md step 1 for the full story).
- Debug interface is **OSJTAG**, on-board, via USB port **J8** (not
  OSBDM).
- The exact chip is **MC56F83789**.
- Headless build driver is **`ecd.exe`**, syntax:
  `ecd.exe build -data <workspace> -project <path> -config <name> [-cleanBuild]`
  — **verified working end-to-end**: `hello_world` builds clean to a
  154 KB `.elf` with CW 11.2 + SP1, after fixing the empty "Additional
  Libraries" linker setting the SDK ships that project with (see
  docs/SETUP.md step 5).
- Debugger Shell scripting driver is **`cwide.exe`/`cwidec.exe`**.
- Flash programmer is **`fflash.exe`**, syntax:
  `fflash <flash.cfg> <image> [-USB] [options]`.
- The **MCUXpresso SDK** for this board ships real, working example
  projects (`hello_world`, `driver_examples/gpio/button_toggle_led`) with
  correct linker files and device headers — the right source for
  `project/`, not hand-written register pokes.

**Also confirmed, on real hardware:** flash → run → verified. `flash/
flash.cfg` is CodeWarrior's own `MC56F837xx.cfg` (targets `mc56f83789`
despite the filename) — `hello_world` was flashed to a physical
MC56F83000-EVK and its `hello world.` banner read back over the OSJTAG
serial bridge. First-time board+toolchain pairings need a one-time JM60
firmware update (via CodeWarrior's IDE, bridging jumper J6) — see
docs/SETUP.md step 6. Also: `FFLASH.exe`'s CLI has a real bug where a
failed connection exits silently with zero output — use the GUI
`56800E Flash Programmer.exe` to see actual errors if `Flash.ps1` fails
mysteriously (docs/SETUP.md step 6 has the full diagnosis).

**Not yet verified** (flagged inline in the scripts; confirm once you have
CodeWarrior installed, against the docs that ship with it):

- The exact flag `cwide.exe`/`cwidec.exe` uses to point at a startup TCL
  script (`Debug.ps1` uses the common Eclipse-launch shape
  `-Dcw.script=<path>` as a starting guess) — confirmed *not* a bare CLI
  flag; `cwidec.exe -help` isn't recognized and instead drops into an
  interactive TCL REPL on stdin, so the real mechanism is likely stdin
  redirection or an in-REPL `source` command.
- Whether `fflash.exe` has a dedicated "reset and run after programming"
  flag, or whether that's a `.cfg` file setting.
- The exact TCL command vocabulary the Debugger Shell accepts
  (`debug/common.tcl` documents the assumption).

## License

Scripts and docs in this repo: MIT (see [LICENSE](LICENSE)). This does not
cover NXP CodeWarrior, the MCUXpresso SDK, or P&E/OSJTAG drivers, which
remain under their respective vendor licenses.
