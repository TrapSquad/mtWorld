package require tls

proc connect {addr port script} {
	if {[string index $port 0] == "+"} { set port [string range $port 1 end] ; set comd ::tls::socket } {set comd socket}
	set sck [$comd $addr $port]
	fconfigure $sck -blocking 0 -buffering line
	fileevent $sck readable [concat $script $sck]
	return $sck
}

proc bind {sock type client comd script} {
	set moretodo 1
	while {0!=$moretodo} {
		set bindnum [rand 1 10000000]
		if {[tnda get "binds/$sock/$type/$client/$comd/$bindnum"]!=""} {} {set moretodo 0}
	}
	tnda set "binds/$sock/$type/$client/$comd/$bindnum" $script
	return $bindnum
}

proc unbind {sock type client comd id} {
	tnda set "binds/$sock/$type/$client/$comd/$id" ""
}
proc callbind {sock type client comd args} {
	puts stdout [tnda get "binds/mode"]
	if {""!=[tnda get "binds/$sock/$type/$client/$comd"]} {
		foreach {id script} [tnda get "binds/$sock/$type/$client/$comd"] {
			if {$script != ""} {$script {*}$args}
		};return
	}
	#if {""!=[tnda get "binds/$type/-/$comd"]} {foreach {id script} [tnda get "binds/$type/-/$comd"] {$script [lindex $args 0] [lrange $args 1 end]};return}
}

proc ndaenc {n} {
	return [string map {/ [} [::base64::encode [string tolower $n]]]
}

proc ndadec {n} {
	return [::base64::decode [string map {[ /} $n]]
}

