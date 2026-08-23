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
board (e.g. `SDK_2.7.1_MC56F83000-EVK` or whatever the current version
is) from NXP's MCUXpresso SDK builder. This is what provides real,
verified example projects — you need this to seed `project/` (step 5).

## 3. Connect the board

Plug the MC56F83000-EVK into USB via **port J8** (on-board OSJTAG debug +
USB-to-UART bridge — confirmed from NXP's setup guide, not the OSBDM path
some older 56800E boards use). Windows should enumerate the OSJTAG debug
interface and a USB CDC serial port.

If it's the first time this board has been connected to this PC,
CodeWarrior may prompt to update the on-board JM60 firmware — this
requires briefly bridging jumper **J6** and following CodeWarrior's
on-screen instructions. The OSJTAG and USB CDC drivers are bundled with
the CodeWarrior installer.

## 4. Detect the command-line tools

```powershell
.\tools\Detect-Toolchain.ps1 -CwRoot "C:\Freescale\CW MCU v11.2"
```

This scans the install tree for `ecd.exe`, `cwide.exe`/`cwidec.exe`,
`fflash.exe`, and `make.exe`, prints what it found, and writes
`config/toolchain.ps1`. These four executable names are confirmed real
(see docs/ARCHITECTURE.md for sources) — detection should succeed
cleanly. If `fflash.exe` isn't found, it may live under a separate "56800E
Flash Programmer" sub-install rather than the main CodeWarrior tree —
check `{CodeWarrior install}\..\` siblings, or reinstall selecting the
Flash Programmer component.

## 5. Seed `project/` from a known-good example

Rather than hand-writing register-level startup code (risky — wrong
addresses silently misbehave on real hardware), copy a real project from
the SDK:

- **To verify the whole pipeline first**, copy the contents of
  `<sdk_install>\boards\evkmc56f83000\demo_apps\hello_world\codewarrior\`
  into this repo's `project/` folder. It prints "hello world" over the
  OSJTAG-bridged COM port (115200 8N1 — find the port number in Device
  Manager under Ports (COM & LPT)).
- **To start your own application**, copy
  `<sdk_install>\boards\evkmc56f83000\driver_examples\gpio\button_toggle_led\codewarrior\`
  instead (the real on-board-LED example), or download the
  `project_template_MC56F83789` package linked from the SDK docs for a
  minimal starting point (startup code, device headers, linker file, no
  demo logic).

Also copy or create `flash/flash.cfg` from whatever `.cfg` the chosen
example project references for its OSJTAG launch configuration — see
`flash/flash.cfg.example` for what's confirmed about its format.

### Known gap in the SDK's `hello_world` project — check before you build

The `hello_world` demo's `.cproject` (as generated by MCUXpresso SDK
26.06.00) ships with an **empty "Additional Libraries" linker setting**
for all four build configs. Without it the link fails with pages of
`Undefined : "Fmemset"` / `"ARTDIVU32UZ_2"` / `"INTERRUPT_SAVEALL"` etc.
— those symbols live in the EABI runtime libraries
(`DSP56800x_EABI_Tools/lib/lpm/{ldm,sdm}/o4p/{libc,librt}.lib`), and
nothing tells the linker to pull them in. Four *other* demos in the same
SDK checkout (`bootloader`, `bubble_peripheral`, `dac_external_sync/*`)
have this populated correctly, so it's a gap specific to `hello_world`,
not a toolchain issue.

Fix: in `project/codewarrior/.cproject`, find each of the four (one per
build config) `<option ... name="Additional Libraries" ...></option>`
blocks and add the matching pair, e.g. for an `ldm` config:

```xml
<listOptionValue builtIn="false" value="&quot;${MCUToolsBaseDir}/DSP56800x_EABI_Tools/lib/lpm/ldm/o4p/librt.lib&quot;"/>
<listOptionValue builtIn="false" value="&quot;${MCUToolsBaseDir}/DSP56800x_EABI_Tools/lib/lpm/ldm/o4p/libc.lib&quot;"/>
```

(swap `ldm` for `sdm` on the two sdm configs). This repo's copy already
has the fix applied — if you re-seed `project/` from a fresh SDK copy,
you'll need to reapply it, or check whichever demo you're seeding from
for the same empty-tag gap first.

## 6. Build, flash, debug

```powershell
.\tools\Build.ps1                              # -Config flash_ldm_lpm_debug by default
.\tools\Flash.ps1
.\tools\Debug.ps1 -Script debug\session.tcl
```

If `Flash.ps1` can't find the board, confirm it enumerates in Device
Manager and that no other CodeWarrior/P&E process is holding the debug
interface open — only one client can use it at a time.

### `flash/flash.cfg` — where it actually comes from

Copy it from `{CodeWarrior install}\MCU\M56800x Support\56800E flash
programmer\MC56F837xx.cfg` — despite the "837xx" filename, its content
targets `mcu mc56f83789` directly (open it and check the `mcu` line if a
future CodeWarrior release renames or reorganizes these). This is a
confirmed-working file, not a guess — verified by actually flashing and
running `hello_world` on real hardware with it.

### First connection to a new board: JM60 firmware update

The very first time this exact board pairs with this CodeWarrior
install, expect a JM60 on-board-probe firmware update prompt (per NXP's
getting-started guide). It only appears through the full CodeWarrior
**IDE** (`eclipse\cwide.exe`) — not the standalone flash programmer —
when you Debug-launch the project for the first time:
`hello_world_flash_ldm_lpm_debug_OSJTAG`. It'll prompt you to briefly
bridge jumper **J6** on the board (small 2-pin header, silkscreened
"J6", near the J8 debug/UART USB connector) and walk you through the
rest. Do this once per board+toolchain-version pairing before expecting
`FFLASH.exe` or `Flash.ps1` to connect successfully — skipping it
produces an opaque **"unknown connection error"**.

### `FFLASH.exe`'s silent-failure CLI bug

The command-line `FFLASH.exe` (what `Flash.ps1` drives) has a real bug:
when it can't connect (e.g. because the JM60 firmware update above
hasn't been done yet, or the board isn't on J8), it exits with a bare
`exit code 1` and **prints nothing at all** — no stderr text, no log
file even with `-l<file>`, and nothing in the Windows Event Log either
(it's a clean, deliberate exit, not a crash). This reproduces identically
whether run interactively, as Administrator, or headlessly — none of
those are the cause. If `Flash.ps1` fails silently, don't spend time on
permissions or session-isolation theories (already ruled out) — instead
run the GUI `56800E Flash Programmer.exe` in the same folder with the
same `flash.cfg`/target once; it surfaces the real error text
(`"could not read the configuration file"`, `"unknown connection
error"`, etc.) that the CLI swallows. Fix whatever it reports, confirm
the GUI succeeds, then `FFLASH.exe`/`Flash.ps1` will work too.

## 7. Debugger Shell TCL command names, and the exact script-launch flag

Two specifics are placeholders until verified against your actual
install (see docs/ARCHITECTURE.md "What's still a documented placeholder"):

- The flag `cwide.exe`/`cwidec.exe` uses to point at a startup TCL script
  — `tools/Debug.ps1` guesses the common Eclipse-launch shape
  `-Dcw.script=<path>`. Confirmed *not* right as a bare CLI flag:
  `cwidec.exe -help`/`-?` doesn't print help and isn't recognized —
  invoking `cwidec.exe` with no recognized arguments drops straight into
  an interactive TCL REPL reading from stdin instead. A script is most
  likely fed via stdin redirection or a TCL `source` command from within
  that REPL, not a command-line flag — still needs confirming against
  the actual Debugger Manual.
- The TCL command vocabulary itself (`debug/common.tcl`).

Open `{CodeWarrior install}\Help\` and look for the Debugger Manual /
Common Features Guide for v11.2, and adjust `tools/Debug.ps1` and
`debug/common.tcl` to match — once fixed, every script here picks up the
correction automatically.
