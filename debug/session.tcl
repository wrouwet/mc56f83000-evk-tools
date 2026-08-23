# Example scripted debug session: connect, load, set a breakpoint at
# main, run to it, dump registers, then single-step a few times.
#
# This is a template to extend, not a finished tool — add breakpoints,
# watchpoints, or memory inspection specific to what you're debugging.
# See debug/common.tcl for the caveat on exact command names.
#
# Usage: tools\Debug.ps1 -Script debug\session.tcl

source [file join [file dirname [info script]] common.tcl]

cw_connect
cw_reset
cw_load [lindex $argv 0]

puts "Setting breakpoint at main..."
# e.g.: bp main

cw_run

puts "Hit breakpoint (expected). Dumping registers:"
cw_dump_registers

puts "Single-stepping 5 instructions..."
for {set i 0} {$i < 5} {incr i} {
    # e.g.: step
    puts "  step $i"
}

puts "Session script complete. Target left halted."
