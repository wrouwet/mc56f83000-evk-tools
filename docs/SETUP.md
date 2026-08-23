# Setup walkthrough

## 1. Install NXP CodeWarrior for MCUs v11.1

- Go to NXP's product page for **"CodeWarrior® for MCUs"** (product code
  `CW-MCU10`; supports ColdFire, 56800/E DSC, Qorivva 56xx, RS08, S08,
  S12Z). Search nxp.com for that product code if the direct link has
  moved — NXP reorganizes these URLs periodically.
- You'll need a free NXP account to download and to request the (free)
  node-locked license.
- Install **v11.1**, then apply **Update 3** (`CW_MCU_11_1_Update3_...zip`)
  — either via Help → Install New Software inside CodeWarrior once it's
  running, or offline via the downloaded zip. This update is what adds
  MC56F83xxx device support to the DSC toolchain — confirmed from NXP's
  MCUXpresso SDK getting-started guide for this board.
- Default install path is typically under `C:\Freescale\CW MCU v11.1` —
  note wherever you actually install it, you'll pass it to
  `Detect-Toolchain.ps1` in step 4.

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
.\tools\Detect-Toolchain.ps1 -CwRoot "C:\Freescale\CW MCU v11.1"
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

## 6. Build, flash, debug

```powershell
.\tools\Build.ps1                              # -Config flash_ldm_lpm_debug by default
.\tools\Flash.ps1
.\tools\Debug.ps1 -Script debug\session.tcl
```

If `Flash.ps1` can't find the board, confirm it enumerates in Device
Manager and that no other CodeWarrior/P&E process is holding the debug
interface open — only one client can use it at a time.

## 7. Debugger Shell TCL command names, and the exact script-launch flag

Two specifics are placeholders until verified against your actual
install (see docs/ARCHITECTURE.md "What's still a documented placeholder"):

- The flag `cwide.exe`/`cwidec.exe` uses to point at a startup TCL script
  — `tools/Debug.ps1` guesses the common Eclipse-launch shape
  `-Dcw.script=<path>`.
- The TCL command vocabulary itself (`debug/common.tcl`).

Open `{CodeWarrior install}\Help\` and look for the Debugger Manual /
Common Features Guide for v11.1, or run `cwidec.exe -help` /
`cwidec.exe -?` directly, and adjust `tools/Debug.ps1` and
`debug/common.tcl` to match — once fixed, every script here picks up the
correction automatically.
