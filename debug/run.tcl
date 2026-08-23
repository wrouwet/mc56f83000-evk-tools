# Minimal load-and-run script: connect, reset, load the ELF, run.
# Usage: tools\Debug.ps1 -Script debug\run.tcl

source [file join [file dirname [info script]] common.tcl]

cw_connect
cw_reset
cw_load [lindex $argv 0]
cw_run
