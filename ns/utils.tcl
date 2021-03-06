proc lshift {listVar {count 1}} {
    upvar 1 $listVar l
    if {![info exists l]} {
	# make the error message show the real variable name
	error "can't read \"$listVar\": no such variable"
    }
    if {![llength $l]} {error Empty}
    set r [lrange $l 0 [incr count -1]]
    set l [lreplace $l [set l 0] $count]
    return $r
}

proc parse_args {argv opts_array} {
    upvar 1 $opts_array opts
    while {[llength $argv] > 0} {
	set arg [lshift argv]
	set match ""
	regexp {^--(.+)=(.+)$} $arg match optname optvalue
	if {[string length $match] > 0} {
	    set opts($optname) $optvalue
	} else {
	    error "Options must be given in the form: --opt=value"
	}
    }
}

proc setdefault {varname defval} {
    upvar 1 $varname v
    if {! [info exists v]} {set v $defval}
}

proc csv_fields {arrayname} {
    upvar 1 $arrayname a
    set sorted [lsort [array name a]]
    if {[string first "," $sorted] == -1} {
	return [join $sorted ", "]
    } else {
	error "One of the fields contains a comma"
    }
}

proc csv_line {arrayname} {
    upvar 1 $arrayname a
    set sorted [lsort [array name a]]
    if {[string first "," $sorted] != -1} {
	error "One of the fields contains a comma"
    }
    set vs [list]
    foreach k $sorted {
	if {[string first "," $a($k)] != -1} {
	    error "One of the values contains a comma"
	}
	lappend vs $a($k)
    }
    return [join $vs ", "]
}
