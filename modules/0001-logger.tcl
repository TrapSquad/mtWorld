bind [dict get $::mts sock] evnt - signon mtLog:Signon
bind [dict get $::mts sock] evnt - signoff mtLog:Signoff

mtNewNick mtOpServ oper services. "mtServices Control"

package require ip

proc binToString {binip} {
	set stringip [::ip::ToString $binip]
	if {[::ip::IPv6? $stringip]} {return [::ip::contract $stringip]} {return $stringip}
}

proc mtLog:Signon {u} {
	mtNotice [dict get $::mts name] $::srvchan [format "Connecting user %s - ident=%s host=%s vhost=%s via=%s nickip=%s" $u [dict get $::mts nicks $u ident] [dict get $::mts nicks $u rhost] [dict get $::mts nicks $u vhost] [dict get $::mts nicks $u serveron] [binToString [dict get $::mts nicks $u nickip]]]
}

proc mtLog:Signoff {u} {
	mtNotice [dict get $::mts name] $::srvchan [format "Disconnecting user %s no longer known to mtWorld" $u]
}

bind [dict get $::mts sock] pub - "h" mtLog:h
bind [dict get $::mts sock] msg mtopserv "addh" mtLog:addh
bind [dict get $::mts sock] msg mtopserv "delh" mtLog:delh

proc mtLog:h {f c t} {
	mtPrivmsg mtOpServ $c [format "^ %s" $t]
}

proc mtLog:addh {f x t} {
	set c [lindex [split $t " "] 0]
	mtNotice mtOpServ $f [format "Adding h to %s" $c]
	mtJoin mtOpServ $c v
	mtPrivmsg mtOpServ $c [format "I was added to %s by %s" $c $f]
	nda set "hchans/[ndaenc $c]" 1
}

proc mtLog:delh {f x t} {
	set c [lindex [split $t " "] 0]
	mtNotice mtOpServ $f [format "Deleting h from %s" $c]
	mtPrivmsg mtOpServ $c [format "I was deleted by %s" $c $f]
	mtPart mtOpServ $c "Vanishing from view..."
	nda set "hchans/[ndaenc $c]" 0
}

bind [dict get $::mts sock] evnt - synched mtLog:Synched
proc mtLog:Synched {} {
	mtNotice [dict get $::mts name] $::srvchan [format "mtWorld is now believed to be synchronised to the IRC network." [dict get $::mts name]]
	foreach {k v} [nda get "hchans"] {
		if {$v == "1"} {
			mtJoin mtOpServ [ndadec $k] v
		}
	}
}
