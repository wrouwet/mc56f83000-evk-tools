# MC56F83000-EVK CLI Toolchain

A `make`-driven build/flash environment for the NXP **MC56F83000-EVK**
evaluation board (MC56F83789, 56800E DSC core). Edit in VS Code (or any
editor), build with `make`, flash with `make flash`. No IDE required.

## Read this first: what this repo is and isn't

The 56800E core is a proprietary hybrid DSP/MCU architecture. There is
**no upstream GCC or LLVM backend** for it. The only realistic compiler
is the one NXP ships with **CodeWarrior for DSC v11.2 + SP1** (free to
download and register, but closed-source). That's a hard constraint, not
a preference.

What this repo does is use *only* CodeWarrior's command-line compiler,
assembler, linker, and flash programmer — driven from an ordinary
Makefile. Its Eclipse IDE, its project file format (`.cproject`/
`.project`), and its `ecd.exe` project driver are not used at all.

- ✅ Ordinary `make build` / `make flash` / `make clean`, calling
  `mwcc56800e.exe` / `mwasm56800e.exe` / `mwld56800e.exe` / `FFLASH.exe`
  directly
- ✅ **Verified end to end on real hardware** — builds, flashes,
  CRC-verifies, and runs: heartbeat LED blinking and the startup banner
  read back over the board's serial bridge
- ✅ Everything here (Makefile, the one PowerShell setup script, docs)
  is yours, MIT-licensed
- ❌ CodeWarrior and the MCUXpresso SDK are NXP's — installed
  separately, referenced by path, not redistributed here
- ⚠️ No live-debug (breakpoints/stepping) story. There's no GDB target
  for this core, and CodeWarrior's scriptable Debugger Shell was never
  made to work headlessly (see "What's confirmed" below). The supported
  loop is **build → flash → reset → observe over serial**.

## Prerequisites

1. **NXP CodeWarrior for DSC v11.2 + SP1** — from NXP's "CodeWarrior for
   56800 Digital Signal Controller v11.2" product page (product code
   `CW-DSC`) — **not** the "CodeWarrior for MCUs v11.1" page, which is a
   different, older product that cannot build current SDK releases for
   this board. Free, requires a (free) NXP account.
   See [docs/SETUP.md](docs/SETUP.md) step 1 for the three files needed.
2. **MCUXpresso SDK for MC56F83000-EVK** — separate download from NXP's
   MCUXpresso SDK builder. Provides the device headers, drivers, startup
   code, and runtime this build compiles against.
3. **GNU Make** and a **POSIX shell**. CodeWarrior bundles `make.exe`
   (`{CW install}\gnu\bin`); Git for Windows supplies the shell. Both are
   located automatically by the setup script in step 1 of Quick start.
4. Windows 10/11. (CodeWarrior for DSC is Windows-only — NXP's
   constraint, not this repo's.)
5. The MC56F83000-EVK, connected via its on-board **OSJTAG** USB port,
   silkscreened **J8**.
6. Optional: **VS Code** + the Microsoft C/C++ extension, for editing
   and `Ctrl+Shift+B` builds. See [docs/SETUP.md](docs/SETUP.md) step 5.

## Quick start

```powershell
# One-time "configure": finds the CodeWarrior tools, the GDI driver, GNU
# Make and a POSIX shell, and writes config/toolchain.mk.
.\tools\Detect-Toolchain.ps1 -CwRoot "C:\Freescale\CW MCU v11.2" -SdkRoot "C:\path\to\SDK_..._MC56F83000-EVK"
```

Everything after that is just `make` — from any shell:

```bash
make build     # compile + link -> build/flash_ldm_lpm_debug/hello_world.elf
make flash     # program the board over OSJTAG (then press reset)
make clean
```

In VS Code, `Ctrl+Shift+B` runs `make build`; a `flash` task is also
defined. See [.vscode/tasks.json](.vscode/tasks.json).

> **After `make flash`, press the board's reset button.** `fflash` leaves
> the target halted and has no documented reset-and-run flag — confirmed
> on hardware.

## Layout

```
Makefile              the actual build — compiler/linker flags and rules
src/                  application sources (hello_world and its board setup)
linker/               linker command files (.cmd) + device .mem/.tcl
flash/                flash.cfg — device/interface config for fflash.exe
config/               toolchain.mk — machine-specific paths (generated, gitignored)
tools/                Detect-Toolchain.ps1 — the one-time "configure" step
.vscode/              build/flash tasks, IntelliSense config template
docs/                 SETUP.md (install walkthrough), ARCHITECTURE.md (why, with citations)
```

Device drivers, startup code, and runtime libraries are **not** vendored
here — they're referenced by path out of your MCUXpresso SDK and
CodeWarrior installs, via `SDK_ROOT`/`CW_ROOT` in `config/toolchain.mk`.

## The firmware

`src/` holds NXP's `hello_world` demo for this board, lightly modified.
On reset it initialises the board, prints over the debug UART:

```
MCUX SDK version: 2026.06.00
hello world.
```

then blinks a **green heartbeat LED at ~2 Hz** forever. The blink is
there so you can tell the board is alive with no UART attached — useful,
given there's no debugger (see below).

Serial is **115200 8N1** on the CDC port the board enumerates (find it
in Device Manager under Ports, or look for USB vendor ID `15A2`).

The stock demo echoed UART input back; that was dropped because
`GETCHAR()` blocks, which would stall the heartbeat whenever nothing was
being typed. If you want both, poll the UART non-blockingly instead of
restoring the blocking loop.

## What's confirmed vs. still unverified

**Confirmed, with sources** (see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)):

- CodeWarrior for DSC **v11.2 + SP1** is what current MCUXpresso SDK
  releases require for this board — confirmed from NXP's own current SDK
  build docs, and the hard way: v11.1 + Update 3 was tried first and
  provably cannot build this SDK release.
- The exact chip is **MC56F83789**; debug interface is on-board
  **OSJTAG** via USB port **J8** (not OSBDM).
- Compiler/assembler/linker are `mwcc56800e.exe` / `mwasm56800e.exe` /
  `mwld56800e.exe`. Their full flag sets in the Makefile were transcribed
  from the `.args` response files of a real, working build — not guessed.
- Flash programmer is `FFLASH.exe`, syntax
  `fflash <flash.cfg> <image> [-USB] [options]`.
  **`-gdi=<path to dsc_pne_gdi.dll>` is mandatory** for this board — see
  the gotcha below.
- `flash/flash.cfg` is CodeWarrior's own `MC56F837xx.cfg`, which targets
  `mc56f83789` despite the filename.
- **Verified on hardware**: `make build` → `make flash` → reset gives a
  blinking heartbeat LED and the `hello world.` banner over the serial
  bridge.
- `fflash` leaves the target **halted** after programming — there's no
  reset-and-run flag, so press the board's reset button.

**Two gotchas worth knowing before you lose an afternoon:**

- **`FFLASH.exe` fails silently without `-gdi=`.** Given no explicit GDI
  driver it picks a default that can't reach this board's OSJTAG probe,
  then exits non-zero printing *nothing at all* — no stderr, no `-l`
  logfile content, nothing in the Windows Event Log. The Makefile always
  passes it. (docs/SETUP.md step 6)
- **A first-time board + toolchain-version pairing needs a one-time JM60
  firmware update**, which only CodeWarrior's IDE can perform (it
  prompts you to bridge jumper **J6**). Symptom without it: "unknown
  connection error". This is the one and only time the IDE is needed.
  (docs/SETUP.md step 6)

**Not verified / not supported:**

- **Live debugging.** `cwidec.exe` takes no script flag (`-help` isn't
  even recognized; it drops into an interactive TCL REPL on stdin), so
  headless scripted debugging was never made to work. Removed rather
  than left in as a non-functional placeholder. Use serial `PRINTF` —
  or CodeWarrior's IDE, if you genuinely need breakpoints.
- Only the **`flash_ldm_lpm_debug`** configuration is implemented — the
  one config with confirmed-good flags. `sdm`/`release` variants would
  need their flags confirmed the same way; the Makefile errors clearly
  rather than guessing.

## License

Scripts and docs in this repo: MIT (see [LICENSE](LICENSE)). This does not
cover NXP CodeWarrior, the MCUXpresso SDK, or P&E/OSJTAG drivers, which
remain under their respective vendor licenses.
