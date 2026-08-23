# MC56F83000-EVK CLI Toolchain

A local, command-line-only build / flash / debug environment for the NXP
**MC56F83000-EVK** evaluation board (MC56F83xxx family, 56800E DSC core),
driven entirely from PowerShell — no IDE window required for day-to-day work.

## Read this first: what this repo is and isn't

The 56800E core is a proprietary hybrid DSP/MCU architecture. There is
**no upstream GCC or LLVM backend** for it, and no open-source debug stack
that reliably talks to this board's on-board OSBDM debug circuit (the
open-source USBDM project explicitly documents its 56800E GDI path as
broken — see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)).

That means the only realistic compiler/assembler/linker/debugger for this
chip is **NXP CodeWarrior for 56800/56800E**, which is free to download and
register but is closed-source. This repo does **not** bundle it — it
bundles scripts that drive it from the command line instead of the Eclipse
GUI. You still need to install CodeWarrior once; everything after that is
scriptable.

So concretely:

- ✅ Fully scriptable, IDE-free build → flash → run → debug loop
- ✅ Everything here (Makefile, PowerShell scripts, TCL debug scripts) is
  yours, MIT-licensed, and lives in this repo
- ❌ The compiler/assembler/linker/flash-programmer/debugger binaries are
  NXP's, installed separately, referenced by path — not redistributed here
- ⚠️ Exact command-line tool names differ across CodeWarrior versions, so
  this repo **auto-detects** them from your install rather than hardcoding
  a guess (see `tools/Detect-Toolchain.ps1`)

## Prerequisites

1. **NXP CodeWarrior for 56800/56800E** (Development Studio for 56800/56800E
   Digital Signal Controllers, "Classic" IDE line — v8.3 / v10.x / v11.2).
   Free download from NXP, requires a (free) NXP account to register the
   license. See [docs/SETUP.md](docs/SETUP.md) for the exact product page.
2. Windows 10/11 with PowerShell (you already have this).
3. The MC56F83000-EVK board, connected via its on-board OSBDM USB port.
4. P&E Micro / OSBDM USB drivers — installed alongside CodeWarrior, or from
   [pemicro.com](https://www.pemicro.com/opensda/).
5. Optional: `make` (e.g. via MSYS2/Git Bash, which you already have) if you
   prefer `make build` over `.\tools\Build.ps1`. Not required — the
   PowerShell scripts are the primary interface.

## Quick start

```powershell
# 1. One-time: point this repo at your CodeWarrior install and let it
#    find the real compiler/assembler/linker/flash/debugger executables.
.\tools\Detect-Toolchain.ps1 -CwRoot "C:\Program Files (x86)\Freescale\CW MCU v11.2"

# 2. Build
.\tools\Build.ps1

# 3. Flash + run on the board over OSBDM
.\tools\Flash.ps1 -Run

# 4. Debug (scripted TCL session against CodeWarrior's Debugger Shell)
.\tools\Debug.ps1 -Script debug\session.tcl
```

`make build`, `make flash`, `make debug`, `make clean` are thin wrappers
around the same scripts, for anyone who wants a `Makefile` entry point.

## Layout

```
config/     toolchain.ps1 — machine-specific tool paths (generated, gitignored)
tools/      Detect-Toolchain.ps1, Build.ps1, Flash.ps1, Debug.ps1
debug/      TCL scripts for CodeWarrior's Debugger Shell
src/        your application source
linker/     linker command file for your exact device (see note below)
docs/       SETUP.md (install walkthrough), ARCHITECTURE.md (why it's built this way)
```

## Important note on `src/` and `linker/`

This repo does **not** ship a hand-written linker command file or
register-level startup code, on purpose: the 56800E memory map and startup
sequence are device-variant-specific (flash/RAM size and layout differ
across the MC56F83xxx family), and getting them wrong silently produces a
binary that misbehaves on real hardware. NXP's own CodeWarrior install
ships a verified example project and linker `.cmd` file for this exact
board under its `Examples`/`Demos` tree.

The fastest path to a **known-correct** first build is:

1. Install CodeWarrior, open the bundled MC56F83000-EVK example project once
   (GUI, one time only) to confirm which exact device variant your board
   has (check the part number silkscreened on the chip, e.g. `MC56F83789`).
2. Copy that example's `.c` sources and `.cmd` linker file into `src/` and
   `linker/` in this repo.
3. From then on, never open the IDE again — use the scripts here.

`src/main.c` in this repo is a placeholder that documents this rather than
guessing register addresses.

## License

Scripts and docs in this repo: MIT (see [LICENSE](LICENSE)). This does not
cover NXP CodeWarrior or P&E/OSBDM drivers, which remain under their
respective vendor licenses.
