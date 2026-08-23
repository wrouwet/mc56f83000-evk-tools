# Why this is built the way it is

## The core has no open compiler

The MC56F83000-EVK is built around a **56800E** core — a hybrid 16-bit
DSP/MCU architecture Freescale designed before the ARM Cortex-M era took
over its microcontroller line. Unlike the boards you'd normally build a
CLI toolchain for (STM32, RP2040, ESP32 — all ARM/RISC-V with mature GCC
backends), the 56800E has never had an upstream GCC or LLVM target. The
compilers that exist for it are:

- **NXP CodeWarrior for 56800/56800E** — free, proprietary, the de facto
  standard, ships with the SDK examples for this board.
- **Cosmic Software's 56800/E cross compiler** — commercial, paid license.

There is no third open option. This repo builds around CodeWarrior because
it's free and is what the board's own example projects target.

## CodeWarrior is an IDE wrapper around real command-line tools

CodeWarrior's Eclipse GUI is not the whole story — underneath it, the
compiler, assembler, and linker are ordinary executables you can invoke
directly, documented in the `56800x_Build_Tools_Reference.pdf` that ships
with the install ("Using the Build Tools on the Command Line" chapter).
They live under the install tree, typically in a path like
`DSP56800x_EABI_Tools\command_line_tools\`. This repo's
`tools/Detect-Toolchain.ps1` scans that tree for them rather than
hardcoding names, because the exact executable names have changed across
CodeWarrior releases (v7.x/v8.x vs v10.x/v11.x naming differs).

## Flashing and debugging: OSBDM, not GDB

The MC56F83000-EVK has an on-board **OSBDM** circuit (an open-hardware BDM
debug interface design) wired to the 56800E's OnCE debug port. Two paths
exist to drive it:

- **CodeWarrior's own stack** (Flash Programmer + GDI debug backend):
  documented to work from a plain command/DOS shell for flashing, and
  CodeWarrior's **Debugger Shell** gives a TCL-scriptable command-line
  debug session (breakpoints, memory/register access, stepping) without
  the Eclipse GUI. This is the path this repo uses.
- **USBDM** (open-source BDM host software): supports a limited range of
  56800E-family parts, but its own documentation states the CodeWarrior
  56800E Flash Programmer's GDI interface **does not work reliably** with
  USBDM/OSBDM on this family — it's flagged as broken upstream. Not used
  here for that reason.

There is also no stock GDB target for the 56800E core, so "debug over
GDB" isn't an option the way it would be for an ARM board — CodeWarrior's
Debugger Shell is the scriptable substitute.

## What "local, command-line only" means in practice here

- Building: 100% CLI, driven by `tools/Build.ps1` calling the real
  compiler/assembler/linker binaries directly.
- Flashing/running: 100% CLI, via the Flash Programmer executable.
- Debugging: CLI-scripted via TCL against the Debugger Shell — you write
  or extend `.tcl` scripts instead of clicking through the Eclipse
  debugger. The Debugger Shell process itself is still an NXP-shipped
  binary (there's no way around that, per above), but nothing here
  requires the Eclipse window to be open.

The one manual, one-time GUI step this repo can't remove: opening
CodeWarrior once to identify/copy the correct example project and linker
`.cmd` file for your exact board variant (see README). After that,
everything is scriptable.
