#!/usr/bin/env tclsh

# Throughput vs winsize
exec rm --force "thr_win.csv"
for { set w 1 } { $w <= 50 } { incr w } {
    exec -ignorestderr ns single_hop.tcl \
	--wait_time=0 --listen_time=0 \
	"--winsize=$w" "--csv_filename=thr_win.csv" --csv_output=1
    puts "winsize = $w OK"
}
