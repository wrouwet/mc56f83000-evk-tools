# Why this is built the way it is

## The core has no open compiler

The MC56F83000-EVK is built around a **56800E** core (device: MC56F83789)
— a hybrid 16-bit DSP/MCU architecture Freescale designed before ARM
Cortex-M took over its microcontroller line. There is no upstream GCC or
LLVM target for it. The realistic compilers are NXP CodeWarrior (free) and
Cosmic Software's 56800/E cross compiler (commercial). This repo builds
around CodeWarrior.

## Confirmed facts, with sources

Everything below was verified against real NXP/Freescale documentation
during setup, not assumed:

**Toolchain version — corrected after actually building, not just
reading docs.** An earlier revision of this file (following NXP's
November 2020 *"Getting Started with MCUXpresso SDK for
MC56F83000-EVK"*, doc `MCUXSDKMC56F83000GSUG`) said CodeWarrior for MCUs
**v11.1 + Update 3** was the right toolchain, and dismissed "CW-DSC
v11.2" as an older, unrelated legacy product. That was correct for the
SDK release that 2020 doc was written against
(`SDK_2.7.1_MC56F83000-EVK`) — it's wrong for current SDK releases.

What actually happened: v11.1 + Update 3, fully installed, builds this
repo's `hello_world` all the way through compilation and then fails at
the link stage two different ways — first with `Linker command file
error ... Expecting: MEMORY` (its bundled linker, even Update 3's 2020
build, doesn't parse the `FLASH_PARTITION{}` block or `AFTER()`
expressions the SDK's generated `.cmd` files use), and, after swapping in
an older static-syntax `.cmd` template to work around that, with
`Undefined : "Fmemset"` / `"ARTDIVU32UZ_2"` / etc. — v11.1's
`DSP56800x_EABI_Tools` tree has no `lib/` subfolder at all, so there's no
`libc.lib`/`librt.lib` to link against no matter what.

**CodeWarrior for DSC v11.2 + SP1** (product code `CW-DSC` — yes, the
same product the 2020 doc calls out as *not* what you want) is what
current MCUXpresso SDK releases actually target, per NXP's present-day
SDK docs (*"Build and run SDK example on codewarrior"*, MCUXpresso SDK
25.06.00/26.06.00 doc tree). Confirmed empirically: v11.2 + SP1's linker
parses the SDK-generated `.cmd` files with no changes needed, and its
`DSP56800x_EABI_Tools/lib/lpm/{ldm,sdm}/o4p/` holds the `libc.lib`/
`librt.lib` every SDK demo project links against. `hello_world` builds
clean to a 154 KB `.elf` on this toolchain (see docs/SETUP.md step 5 for
the one remaining fix that project's own `.cproject` needed).

Other facts from the original research, still holding:
- The on-board debug interface is **OSJTAG**, via USB port **J8** — *not*
  OSBDM. (An external P&E U-MultiLink is also supported, per the debug
  launch configuration names `..._OSJTAG` and `..._PnE U-MultiLink` shown
  in NXP's getting-started guide.)
- The MCUXpresso SDK for this board ships working example projects —
  `hello_world`, `driver_examples/gpio/button_toggle_led`, and others —
  each with a linker command file for the exact device (confirmed
  filename: `MC56F83789_Internal_PFlash_LDM.cmd`) and device headers.
  Per-device "project template" packages are also downloadable
  separately, for starting a custom project without demo application
  code.
- The GUI workflow confirms two real build configuration names per
  memory model: `flash_ldm_lpm_debug` (optimization level 1) and
  `flash_ldm_lpm_release` (optimization level 4) — and their `sdm`
  counterparts.

**Headless build driver** — *"CodeWarrior 10 Command Line Interface –
usage and examples"* (NXP community doc, by Jennie Zhang), confirmed
still present and consistent in v11.1 (same Eclipse CDT-based
architecture):
- `{CodeWarrior install}\eclipse\ecd.exe` is the headless build driver.
- It builds a whole **Eclipse project directory** (one containing a
  `.cproject`/`.project` file) — not loose source files compiled
  individually. This is why this repo's `project/` folder expects a real
  copied-in CodeWarrior project rather than a `src/*.c` file list.
- Confirmed syntax:
  `ecd.exe build -data <workspace-path> -project <project-path> [-config <name> | -allConfigs] [-cleanBuild]`
- A companion mode, `ecd.exe -generateMakefiles ...`, emits a real GNU
  Makefile you can then drive with the `make.exe` CodeWarrior bundles
  under `{install}\gnu\bin\` — useful if you'd rather not shell out to
  `ecd.exe` directly for every build.
- Two sibling executables in the same folder, `cwide.exe` and
  `cwidec.exe`, are confirmed to run **Debugger Shell TCL scripts**
  headlessly — this is the mechanism `tools/Debug.ps1` and `debug/*.tcl`
  in this repo use.

**Flash programmer** — *"56800E Flash Programmer User's Guide"*
(Freescale, Rev. 0, 09/2005):
- Executable name: **`fflash`**.
- Confirmed syntax:
  `fflash <flash.cfg file> <S-Record/ELF file(s)> [options]`
- Target device and debug interface are selected via the `.cfg` file
  passed as the first argument, not command-line flags.
- `-USB` forces the USB interface (this board's OSJTAG path — J8 is a USB
  connector). Other confirmed flags: `-erase=<all|unit|page>`,
  `-jtagclk=<kHz>`, `-l<logfile>`, `-lock`.
- Legacy `-LPT<n>`/`-p<PORT>` flags select a parallel-port Command
  Converter — not relevant to this board's on-board USB debug circuit.

## What's still a documented placeholder, not a guess

A few specifics couldn't be confirmed from publicly available docs before
an actual CodeWarrior install was in hand, and are flagged inline in the
scripts rather than silently assumed:

- The exact flag `cwide.exe`/`cwidec.exe` expects to point at a startup
  TCL script.
- Whether `fflash.exe` has a "run after programming" flag, or whether
  that's configured inside `flash.cfg`.
- The precise TCL command vocabulary the Debugger Shell exposes
  (breakpoints, stepping, register/memory access) — `debug/common.tcl`
  documents the assumed shape and where to verify it
  (`{CodeWarrior install}\Help\`, once installed).

## Why not GDB, and why not the open-source USBDM project

There's no stock GDB target for the 56800E core, so a GDB-based debug flow
(the way you'd do it for an ARM board) isn't an option here. The
open-source USBDM project supports a limited range of 56800E-family parts
but its own documentation states the CodeWarrior 56800E Flash Programmer's
GDI interface doesn't reliably work with USBDM/OSBDM — not used here for
that reason, and moot anyway since this board's default interface is
OSJTAG, which CodeWarrior drives directly via `fflash`/`ecd`/`cwide`.
