# Setup walkthrough

## 1. Install NXP CodeWarrior for DSC v11.2 + SP1 — NOT v11.1

**This is the single most important thing to get right.** CodeWarrior for
MCUs v11.1 (even fully patched with Update 3) is a dead end for any
current-generation MCUXpresso SDK release for this board (2026.06.00 as
of this writing) — its 56800E linker predates the `FLASH_PARTITION{}` /
`AFTER()` syntax the SDK's generated linker command files use, and its
`DSP56800x_EABI_Tools` tree has no `lib/` subfolder at all (no
`libc.lib`/`librt.lib`), which every SDK demo project links against. We
lost real time confirming this the hard way — see the "Why not v11.1"
note below if you want the full story.

**What actually works**, per NXP's own current MCUXpresso SDK docs
(`Build and run SDK example on codewarrior`, and this board's release
notes doc `MCUXSDKMC56F83000RN`): **CodeWarrior Development Studio v11.2
+ CodeWarrior for DSC v11.2 SP1**. This is a *different product line*
from "CodeWarrior for MCUs v11.1" — don't confuse the two NXP product
pages.

- Go to NXP's product page **"CodeWarrior for 56800 Digital Signal
  Controller v11.2"** (product code `CW-DSC`). Search nxp.com for that
  code if the direct link has moved.
- You'll need a free NXP account to download and to request the (free)
  node-locked license. Windows only.
- Download all three of these from the Downloads tab and keep them in
  the same folder (NXP's own instruction):
  - `CW_MCU_v11.2_b221206.exe` — base installer. Run it, select **DSC**
    on the Choose Components screen. This is a full interactive
    InstallAnywhere/NSIS GUI wizard — there's no meaningful silent-install
    path, budget time to click through it.
  - `com.freescale.mcu11_2.dsc.updatesite.zip` — DSC support package.
  - `com.freescale.mcu11_2.DSC_devices.win.sp.v1.0.26.zip` — DSC device
    Service Pack 1. **Don't skip this one** — it's what actually adds
    MC56F83xxx (and other DSC device) support: headers, `.mem`/`.tcl`
    device database entries, and the version-matched
    `MC56F8378x_Internal_PFlash_{LDM,SDM}.cmd` reference linker files.
- Default install path is typically `C:\Freescale\CW MCU v11.2` — note
  wherever you actually install it, you'll pass it to
  `Detect-Toolchain.ps1` in step 4.
- Apply the two zip components via CodeWarrior's own Help → Install New
  Software once the base installer finishes (point it at each zip as a
  local archive repository). If that stalls or errors — the Eclipse
  update mechanism bundled with these DSC releases is genuinely old and
  can be flaky — the zips are just p2 repositories; each contains one
  `binary/*_root_*` entry that is itself a plain zip of the real files
  rooted at `MCU/`. Extracting that nested zip's `MCU/` folder directly
  over the CodeWarrior install directory achieves the same result without
  going through Eclipse at all.

### Why not v11.1 (skip this if you just want to get moving)

If you already have CW MCU v11.1 (+ Update 3) installed from following
older instructions: it will get you *closer* — Update 3 does add
MC56F83xxx device support and a newer (2020) linker/compiler/assembler
triple than the 2018 base install — but it still can't parse the linker
command file syntax current SDK releases generate, and it's missing the
`DSP56800x_EABI_Tools/lib/lpm/...` runtime library layout entirely.
There's no patching your way from 11.1 to what the SDK needs; install
11.2 + SP1 alongside it (or instead of it) rather than trying to bridge
the gap.

## 2. Install the MCUXpresso SDK for MC56F83000-EVK

Separately from CodeWarrior itself: get the SDK build for this exact
board from NXP's MCUXpresso SDK builder (this repo was built and
verified against `SDK_26_06_00_MC56F83000-EVK`). It provides the device
headers, peripheral drivers, startup code and linker command files this
build compiles against.

Note the install path — you'll pass it as `-SdkRoot` in step 4. This
repo does **not** vendor those SDK sources; it references them by path,
so the SDK needs to stay where you put it.

## 3. Install GNU Make, a POSIX shell, and (optionally) VS Code

- **GNU Make** — CodeWarrior already bundles one at
  `{CodeWarrior install}\gnu\bin\make.exe`. Step 4 finds it for you; you
  only need it on your `PATH` to type `make` conveniently.
- **A POSIX shell** — GNU Make on Windows otherwise runs recipes through
  `cmd.exe`, which has no `mkdir -p` or `rm -rf`. Git for Windows ships
  a suitable `bash.exe`; step 4 locates it and records it as Make's
  `SHELL`. If you have Git installed, you already have this.
- **VS Code** (optional) plus the Microsoft **C/C++** extension
  (`ms-vscode.cpptools`), if you want editing + `Ctrl+Shift+B` builds.
  The repo recommends it via `.vscode/extensions.json`.

## 4. Configure: point the build at your installs

```powershell
.\tools\Detect-Toolchain.ps1 -CwRoot "C:\Freescale\CW MCU v11.2" -SdkRoot "C:\path\to\SDK_26_06_00_MC56F83000-EVK"
```

This is the only PowerShell in the workflow — think of it as
`./configure`. It scans the CodeWarrior tree for `mwcc56800e.exe`,
`mwasm56800e.exe`, `mwld56800e.exe`, `FFLASH.exe`, `make.exe` and the
P&E GDI driver, finds a POSIX shell, and writes it all to
`config/toolchain.mk` (gitignored — it's machine-specific).

Everything after this is `make`. See `config/toolchain.mk.example` for
the file's shape if you'd rather write it by hand.

If a tool comes up `[MISSING]`, the likeliest cause is an incomplete
CodeWarrior install — in particular, the **DSC device Service Pack**
from step 1 is what supplies MC56F83xxx support.

## 5. Set up VS Code (optional)

Copy `.vscode/c_cpp_properties.json.example` to
`.vscode/c_cpp_properties.json` and replace the placeholder
`C:/Users/you/SDK_...` and `C:/Freescale/CW MCU v11.2` paths with your
real ones (same values step 4 wrote into `config/toolchain.mk`). That
gives IntelliSense the include paths and `-D` defines the compiler
actually uses.

Two caveats, both deliberate:

- This list has to be **kept in sync by hand** with the Makefile's
  `INCLUDES`/`DEFINES` if either changes. VS Code can't read Make
  variables.
- `intelliSenseMode` is set to `linux-gcc-x86`, which is an
  approximation — there's no IntelliSense mode for the 56800E core.
  Expect occasional false-positive squiggles on core-specific
  intrinsics. The build is the source of truth, not the editor.

`Ctrl+Shift+B` runs `make build`; a `flash` task is also defined in
`.vscode/tasks.json`.

## 6. Connect the board, build, flash, run

Plug the MC56F83000-EVK into USB via **port J8** — check the silkscreen
label on the PCB rather than going by physical position; the board has
more than one USB connector. J8 is the on-board OSJTAG debug +
USB-to-UART bridge (confirmed from NXP's setup guide, not the OSBDM path
some older 56800E boards use). Windows should enumerate an
`OSBDM/OSJTAG - Debug Port` plus a CDC serial port, both under
Freescale/NXP's USB vendor ID `15A2`.

```bash
make build
make flash
```

Then **press the board's reset button** — `fflash` leaves the target
halted and has no documented reset-and-run flag (confirmed on hardware).

The stock `src/hello_world.c` gives you two independent signs of life:

- a **green heartbeat LED** blinking at ~2 Hz (no UART needed), and
- `MCUX SDK version: ...` / `hello world.` over the serial port
  (115200 8N1 — find the COM port in Device Manager under Ports).

### `flash/flash.cfg` — where it actually comes from

Copied from `{CodeWarrior install}\MCU\M56800x Support\56800E flash
programmer\MC56F837xx.cfg` — despite the "837xx" filename, its content
targets `mcu mc56f83789` directly (open it and check the `mcu` line if a
future CodeWarrior release reorganizes these). Confirmed working, not a
guess — verified by flashing and running on real hardware.

### First connection to a new board: JM60 firmware update

The very first time this exact board pairs with this CodeWarrior
install, expect a JM60 on-board-probe firmware update prompt (per NXP's
getting-started guide). It only appears through the full CodeWarrior
**IDE** (`eclipse\cwide.exe`) — not the flash programmer — when you
Debug-launch a project for the first time. It'll prompt you to briefly
bridge jumper **J6** on the board (small 2-pin header, silkscreened
"J6", near the J8 connector) and walk you through the rest.

Do this once per board + toolchain-version pairing before expecting
`make flash` to connect — skipping it produces an opaque **"unknown
connection error"**. This is the one and only time you need the IDE.

### `-gdi=` is mandatory, and omitting it fails *silently*

`FFLASH.exe` must be told which GDI driver to use:

```
-gdi=.../56800E flash programmer/DSC/gdi/dsc_pne_gdi.dll
```

Without it, fflash falls back to a driver that can't reach this board's
OSJTAG probe and exits non-zero having printed **nothing at all** — no
stderr, no content in a `-l<file>` log, nothing in the Windows Event Log
(it's a deliberate exit, not a crash). It reproduces identically
interactively, as Administrator, and headlessly, so none of those are
the cause.

The Makefile always passes `-gdi=$(GDI)`, and step 4 derives that path
from `fflash.exe`'s own directory (a CodeWarrior install carries more
than one copy of that DLL; the one next to `fflash.exe` is the right
one). This is only worth knowing if you invoke `fflash` by hand.

If `make flash` fails some *other* way, check that no other
CodeWarrior/P&E process is holding the debug interface — only one client
can use it at a time, and a stale `cwide.exe` or `ccs.exe` will block
it. The GUI `56800E Flash Programmer.exe` is also useful for diagnosis:
it surfaces real error text that the CLI swallows.

## 7. What about debugging?

There isn't a scripted live-debug story, and this repo no longer
pretends otherwise.

`cwidec.exe` accepts no script flag — `-help` isn't even recognized, and
running it with no recognized arguments drops into an interactive TCL
REPL reading stdin. Earlier versions of this repo shipped placeholder
TCL scripts and a `Debug.ps1` built on a guessed `-Dcw.script=` flag;
none of it worked, so it was removed rather than left as fiction.

There's also no GDB target for the 56800E core (see
docs/ARCHITECTURE.md), so no open-source debug path either.

In practice: **`PRINTF` over the serial port**, plus the heartbeat LED.
If you genuinely need breakpoints and single-stepping, use CodeWarrior's
IDE for that session — the toolchain it installs is the same one this
Makefile drives, so the two coexist fine.
