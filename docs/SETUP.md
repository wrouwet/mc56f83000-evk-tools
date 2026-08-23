# Setup walkthrough

## 1. Install NXP CodeWarrior for 56800/56800E

- Go to NXP's CodeWarrior legacy tools page and find **"CodeWarrior
  Development Studio for 56800/56800E Digital Signal Controllers"**
  (product line `CW-56800E-DSC` / `CW-DSC`, "Classic IDE"). Search
  nxp.com for that product code if the direct link has moved — NXP
  reorganizes these URLs periodically.
- You'll need a free NXP account to download and to request the (free)
  node-locked license for the Standard/Special edition.
- Install to the default path, or note whatever path you choose — you'll
  pass it to `Detect-Toolchain.ps1` in step 3.
- Also install the P&E Micro / OSBDM USB drivers if the installer doesn't
  bundle them (the CodeWarrior installer usually does).

## 2. Connect the board

Plug the MC56F83000-EVK into USB via its on-board OSBDM connector. Windows
should enumerate a P&E/OSBDM USB device. If it shows as "Unknown Device",
install the drivers from the CodeWarrior install or from
<https://www.pemicro.com/opensda/>.

## 3. Identify your exact device variant

Look at the silkscreen on the DSC chip itself (e.g. `MC56F83789`). The
MC56F83xxx family has several flash/RAM sizes — the linker command file
and startup code must match. Open CodeWarrior once, use its "New Project"
wizard or the bundled examples to confirm the exact part CodeWarrior
detects, and note it.

## 4. Detect the command-line tools

```powershell
.\tools\Detect-Toolchain.ps1 -CwRoot "C:\Program Files (x86)\Freescale\CW MCU v11.2"
```

This scans the install tree for the compiler, assembler, linker, flash
programmer, and debugger shell executables, prints what it found, and
writes `config/toolchain.ps1`. If it finds more than one candidate for a
given tool (happens if multiple CodeWarrior versions/families are
installed), it lists them all and asks you to edit `config/toolchain.ps1`
to pick the right one.

If detection finds **nothing** for a given tool, open
`{CodeWarrior install}\Help\` and look for `56800x_Build_Tools_Reference.pdf`
— it names the actual executables for your specific version. Add that path
manually to `config/toolchain.ps1`.

## 5. Seed `src/` and `linker/` from a known-good example

In CodeWarrior, open the example project for MC56F83000-EVK that matches
your device variant (bundled under the install's `Examples` or `Demos`
tree — check `{CodeWarrior install}\MC56800E_Examples\` or similar; the
exact path varies by version). Copy:

- Its `.c`/`.h` sources → this repo's `src/`
- Its linker `.cmd` file → this repo's `linker/`

into this repo, replacing the placeholders. This guarantees a correct
memory map and startup sequence instead of hand-guessed register
addresses.

## 6. Build, flash, debug

```powershell
.\tools\Build.ps1
.\tools\Flash.ps1 -Run
.\tools\Debug.ps1 -Script debug\session.tcl
```

If `Flash.ps1` can't find the board, confirm it enumerates in Device
Manager and that no other instance of CodeWarrior/P&E software is holding
the USB connection open — the OSBDM interface only accepts one client at a
time.

## 7. Debugger Shell TCL command names

The exact TCL command set exposed by CodeWarrior's Debugger Shell can
differ slightly by version. `debug/common.tcl` documents the commands this
repo assumes; if a script errors on an unrecognized command, open
`{CodeWarrior install}\Help\` and look for the Debugger Manual / Debugger
Shell reference for your version, and adjust `debug/common.tcl` to match.
