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
clean on this toolchain, flashes, and runs on real hardware.

(A footnote from that era, now moot: the SDK's `hello_world.cproject`
also shipped with an empty "Additional Libraries" linker setting, so it
failed to link against those runtime libraries even under v11.2 — four
sibling demos in the same SDK had it populated correctly. That gap
disappeared along with the Eclipse project files; the Makefile passes
`librt.lib`/`libc.lib` explicitly.)

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

## Why the build doesn't use Eclipse project files or `ecd.exe`

Earlier revisions of this repo drove CodeWarrior's headless Eclipse
build driver (`ecd.exe build -data <workspace> -project <path> -config
<name>`) against a `.cproject`/`.project` pair copied out of the SDK.
That works — but only from the SDK's own directory, which makes it
useless for a self-contained repo.

The reason is in `.project`: every device/driver source it pulls in is a
*linked resource* declared as `PARENT-5-PROJECT_LOC/devices/MC56F83789/
...` — "go up exactly five directories from wherever this file lives,
then descend." That resolves correctly only at the SDK's original depth
(`boards/<board>/demo_apps/<name>/codewarrior/`). Copied into this repo
at `project/codewarrior/`, five-up landed on `C:\Users\` and the build
failed with `No rule to make target 'C:/Users/devices/...'`. The
successful builds during that era were, on inspection, all pointed
straight at the SDK checkout — the repo's own copy never actually built.

Rather than patch the paths (fragile, and re-broken by every re-seed),
the build now calls the underlying tools directly from an ordinary
Makefile, computing every path from an explicit `SDK_ROOT`/`CW_ROOT` in
`config/toolchain.mk`. No relative-depth assumptions, no Eclipse
metadata, no IDE.

**The compiler/assembler/linker flag sets in the Makefile are not
reverse-engineered guesses.** They're transcribed from the `.args`
response files that a real, verified `flash_ldm_lpm_debug` build
emitted under `.../hello_world/codewarrior/build/flash_ldm_lpm_debug/`.
So the Makefile reproduces a known-good build; it just orchestrates it
itself. (One deliberate cleanup: the assembler's `.args` repeated
several `-i` include paths verbatim, an Eclipse generation artifact,
de-duplicated here.)

`ecd.exe`'s companion mode `-generateMakefiles` also exists and emits a
GNU Makefile — but it emits one *for the Eclipse project*, inheriting
the same linked-resource problem, so it isn't a way out.

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
- **`-gdi=<dll>` is mandatory here, and omitting it fails silently.**
  The manual presents it as optional. In practice, without
  `-gdi=.../DSC/gdi/dsc_pne_gdi.dll` fflash cannot reach this board's
  on-board OSJTAG probe and exits non-zero having printed *nothing* — no
  stderr, no `-l<file>` content, no Event Log entry. It is a deliberate
  exit, not a crash, and reproduces identically interactively, elevated,
  and headless. Established empirically: the same command differing only
  in that flag goes from silent failure to
  `Verification Passed CRC32 (...)`.
- Confirmed empirically: fflash **leaves the target halted** after
  programming. Nothing in the manual's flag list resets-and-runs, and
  the board only starts the new firmware after a manual reset.

## What's still unverified

- The precise TCL command vocabulary CodeWarrior's Debugger Shell
  exposes. Not pursued further, because the shell can't be driven
  headlessly in the first place (below), so the vocabulary is moot for
  this repo.

## Why there's no scripted debugging

`cwide.exe`/`cwidec.exe` are frequently described as running Debugger
Shell TCL scripts headlessly. They may well do so under the IDE, but
there is no working command-line entry point: `cwidec.exe -help` and
`-?` are not recognized, and invoking it with no recognized arguments
drops into an **interactive TCL REPL reading stdin** rather than
printing usage. An earlier revision of this repo shipped `tools/
Debug.ps1` built around a guessed `-Dcw.script=<path>` flag plus
placeholder `debug/*.tcl` scripts whose commands were never verified
either. None of it ever ran. It has been removed rather than left in
place as non-functional scaffolding.

Combined with the absence of a GDB target for this core (below), the
supported workflow is `PRINTF` over the serial bridge plus the
heartbeat LED in `src/hello_world.c`. CodeWarrior's IDE remains
available if genuine breakpoint debugging is needed for a session — it
installs the same toolchain this Makefile drives, so the two coexist.

## Why not GDB, and why not the open-source USBDM project

There's no stock GDB target for the 56800E core, so a GDB-based debug flow
(the way you'd do it for an ARM board) isn't an option here. The
open-source USBDM project supports a limited range of 56800E-family parts
but its own documentation states the CodeWarrior 56800E Flash Programmer's
GDI interface doesn't reliably work with USBDM/OSBDM — not used here for
that reason, and moot anyway since this board's default interface is
OSJTAG, which CodeWarrior drives directly via `fflash`/`ecd`/`cwide`.
