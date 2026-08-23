# Working in this repo

This file is for a future Claude Code session (or any AI agent) picking
this project back up. It's a practical reference, not a narrative — for
the "why" behind each of these, see docs/ARCHITECTURE.md and
docs/SETUP.md, which were kept in sync with everything below.

## The one fact that matters most

**Toolchain is CodeWarrior for DSC v11.2 + SP1, installed at
`C:\Freescale\CW MCU v11.2`.** Not v11.1 — that product ("CodeWarrior for
MCUs", `CW-MCU10`) cannot build current MCUXpresso SDK releases for this
board, full stop, no amount of patching bridges the gap (proven
empirically, see docs/ARCHITECTURE.md). If you find yourself debugging a
`Linker command file error ... Expecting: MEMORY` or `Undefined :
"Fmemset"`/`"ARTDIVU32UZ_2"` style link error, you are almost certainly
looking at a v11.1 install — check `config/toolchain.ps1`'s `$CwRoot`
before doing anything else.

If v11.2 + SP1 isn't installed yet, the three files needed (get them
from NXP's "CodeWarrior for 56800 Digital Signal Controller v11.2"
product page, code `CW-DSC` — requires a free NXP account login, which
you cannot do on the user's behalf) are:
- `CW_MCU_v11.2_b221206.exe` — base installer (interactive GUI wizard,
  no real silent-install path; the user needs to click through it,
  selecting the **DSC** component)
- `com.freescale.mcu11_2.dsc.updatesite.zip` — DSC support package
- `com.freescale.mcu11_2.DSC_devices.win.sp.v1.0.26.zip` — device
  Service Pack 1 (MC56F83xxx support)

The two zips are p2 repositories. CodeWarrior's own Eclipse "Install New
Software" mechanism for applying them is old and can be flaky (hit a
real `IllegalStateException` bug in its bundled 2007-era JVM during this
project's setup — a boxed-`Long` comparison bug, not fixable from the
outside). If it fails, don't fight it: each zip's `binary/*_root_*` entry
is itself a plain zip rooted at `MCU/` — extract that directly over the
CodeWarrior install directory (`unzip -o -q <extracted_root_file> -d
"C:\Freescale\CW MCU v11.2"`) and skip Eclipse's installer entirely.

## Known, already-fixed gotchas (don't rediscover these)

1. **`hello_world`'s `.cproject` ships with an empty "Additional
   Libraries" linker setting** (all 4 build configs). Already fixed in
   this repo's `project/codewarrior/.cproject` — if you re-seed
   `project/` from a fresh SDK copy, or start a new project from a
   different SDK demo, check for this before assuming a build failure is
   a toolchain problem. Fix: add
   `${MCUToolsBaseDir}/DSP56800x_EABI_Tools/lib/lpm/{ldm,sdm}/o4p/{librt,libc}.lib`
   references (sibling demos in the same SDK — `bootloader`,
   `bubble_peripheral`, `dac_external_sync/*` — have this populated
   correctly and are a good reference for the exact XML shape).

2. **`FFLASH.exe`'s CLI has a real bug**: a failed connection exits
   silently — `exit code 1`, zero stdout/stderr text, no log file even
   with `-l<file>`, nothing in the Windows Event Log. Reproduces
   identically interactive, as Administrator, or headless — none of
   those are the cause, don't waste time on permission/session theories.
   If `Flash.ps1`/`FFLASH.exe` fails with no explanation, run the GUI
   `{CW install}\MCU\M56800x Support\56800E flash programmer\56800E
   Flash Programmer.exe` with the same `flash.cfg` — it shows the real
   error text.

3. **First-time board+toolchain-version pairing needs a JM60 firmware
   update.** Symptom: GUI flash programmer (or FFLASH.exe) gives
   `"unknown connection error"` after a several-second connection
   attempt. Fix requires the full CodeWarrior **IDE**
   (`eclipse\cwide.exe`), not the standalone flash tool — Debug-launch
   the project once (`hello_world_flash_ldm_lpm_debug_OSJTAG`), it
   detects the mismatch and prompts to bridge jumper **J6** on the
   board briefly, then walks through the update. This is a one-time
   thing per board+toolchain-version combination.

4. **`flash/flash.cfg` comes from `{CW install}\MCU\M56800x Support\
   56800E flash programmer\MC56F837xx.cfg`** — despite the "837xx" in
   the filename, its content targets `mcu mc56f83789` directly (check
   the `mcu` line to confirm on a fresh install). Confirmed working:
   actually flashed and ran `hello_world` on real hardware with this
   exact file.

## Verifying hardware, without asking the user to eyeball a terminal

You have Bash/PowerShell access. To confirm firmware is actually running
on the board rather than asking the user to check a serial terminal
themselves, read the OSJTAG CDC serial port directly:

```powershell
$port = New-Object System.IO.Ports.SerialPort COM4,115200,None,8,One
$port.ReadTimeout = 3000
$port.Open()
Start-Sleep -Milliseconds 500
$port.ReadExisting()
$port.Close()
```

(COM port number varies by machine — find it via `Get-CimInstance
Win32_PnPEntity | Where-Object { $_.DeviceID -match "VID_15A2" }`; the
"OSBDM/OSJTAG - CDC Serial Port" entry names the COM port. VID `15A2` is
Freescale/NXP's own — if instead you see the board enumerate as VID
`10C4`/`PID_EA60` with `Status: Error`/`ConfigManagerErrorCode: 28`,
that's the JM60's CP210x-compatible UART function missing a driver, not
a hardware fault — Windows Update usually has it, but driver install
needs admin rights this environment may not have; the user may need to
do it themselves via Device Manager.)

## USB port identification on the physical board

- **J8** — on-board OSJTAG debug + USB-to-UART bridge. This is the one
  to use for build/flash/debug. Confirm by checking the actual
  silkscreen label on the PCB, not by guessing physical position — this
  board has multiple USB-capable connectors and "the middle one" is not
  reliable across board revisions or how the user has it oriented.
- **J6** — 2-pin jumper header, only bridged briefly during a JM60
  firmware update (see gotcha #3 above). Leave open otherwise.

Don't assume a connected USB device is this board without checking its
USB VID — this board's actual chip is Freescale/NXP silicon (VID
`15A2`) once properly enumerated. Other NXP dev boards (e.g. FRDM/MCU-LINK
boards, VID `1FC9`) are easy to plug in by mistake if multiple boards are
on hand — check `Get-CimInstance Win32_PnPEntity` before assuming you're
looking at the right hardware.

## Build/flash commands that are confirmed working end to end

```powershell
# One-time, after CW 11.2 + SP1 is installed:
.\tools\Detect-Toolchain.ps1 -CwRoot "C:\Freescale\CW MCU v11.2"

.\tools\Build.ps1        # builds project/codewarrior — see caveat below
.\tools\Flash.ps1         # see gotcha #2 if this fails silently
```

**Caveat on `Build.ps1`**: it auto-discovers `.cproject` via recursive
search under `project/`. If `project/` ever ends up holding more than
one `.cproject` (e.g. a stray copy from re-seeding), or if the repo's
tracked copy of `.cproject`/the linker `.cmd` files drifts out of sync
with what's actually being built, prefer invoking `ecd.exe build`
directly against a known project path to sidestep ambiguity — this is
exactly how the working build was actually verified in this repo's
history (see git log / docs/ARCHITECTURE.md), pointed straight at
`project/codewarrior` rather than relying on discovery.

Not yet exercised from this repo's own `tools/Debug.ps1` — the TCL
debugger-shell scripting flag is still an open question (see
docs/SETUP.md step 7). `cwidec.exe` with no recognized args drops into
an interactive TCL REPL on stdin rather than printing help; the script-
launch mechanism is likely stdin redirection or an in-REPL `source`
command, not a bare CLI flag — confirm against `{CW install}\Help\`
before trusting `Debug.ps1`'s current guess.
