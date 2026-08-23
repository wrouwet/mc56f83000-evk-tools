# Shared helpers for CodeWarrior Debugger Shell TCL scripts.
#
# The command names below (connect/target-select via GDI, reset, load,
# go/step/mem/reg) are the conventional CodeWarrior Debugger Shell
# vocabulary used across its device families, but the exact set and
# spelling can differ by CodeWarrior version. If a command here errors as
# "unknown command", open the Debugger Manual PDF shipped under
# {CodeWarrior install}\Help\ for your version and fix the name here —
# once fixed, every script in this directory that sources common.tcl picks
# up the correct command.
#
# See docs/SETUP.md step 7.

proc cw_connect {} {
    puts "Connecting to target over OSBDM..."
    # Typical shape once verified against your version, e.g.:
    #   target connect
    # or (older CW): connect
}

proc cw_reset {} {
    puts "Resetting target..."
    # e.g.: reset
}

proc cw_load {elf_path} {
    puts "Loading $elf_path..."
    # e.g.: load $elf_path
}

proc cw_run {} {
    puts "Running..."
    # e.g.: go
}

proc cw_halt {} {
    puts "Halting..."
    # e.g.: halt
}

proc cw_dump_registers {} {
    puts "Register dump:"
    # e.g.: reg
}
