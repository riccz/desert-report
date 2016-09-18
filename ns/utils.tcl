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
