# Cloaker.

package require rc4
package require md5

if {![info exists ::cloakkey]} {
	putcmdlog "You need to provide a cloak-key in services.conf."
	exit
}

bind [dict get $::mts sock] msg mtopserv "addgwcloak" mtCloak:addtorserver
bind [dict get $::mts sock] msg mtopserv "delgwcloak" mtCloak:deltorserver
bind [dict get $::mts sock] msg mtopserv "lsgwcloak" mtCloak:listtorservers

bind [dict get $::mts sock] evnt - signon mtCloak:docloak

proc mtCloak:listtorservers {f to t} {
	if {![string match "*N*" [dict get $::mts nicks [string tolower $f] umode]]} {
		mtNotice mtopserv $f "You need to be a Network Administrator to use this command. If you are not opered, oper up and try again."
		return
	}
	foreach {server cloaklist} [nda get "gwcloaks"] {
		mtNotice mtopserv $f [format "Begin cloaks for server mask %s --" [ndadec $server]]
		foreach {mask cloak} $cloaklist {
			set msk [ndadec $mask]
			if {$cloak == ""} {continue}
			mtNotice mtopserv $f [format "  Host %s -> Cloak %s" $msk $cloak]
		}
		mtNotice mtopserv $f [format "End cloaks for server mask %s -- " [ndadec $server]]
	}
}

proc mtCloak:addtorserver {f to t} {
	if {![string match "*N*" [dict get $::mts nicks [string tolower $f] umode]]} {
		mtNotice mtopserv $f "You need to be a Network Administrator to use this command. If you are not opered, oper up and try again."
		return
	}
	set s [split $t " "]
	if {[llength $s] < 3} {mtNotice mtopserv $f "I, uh, I didn't see all the arguments I needed.";return}
	set cloaksrv [lindex $s 0]
	set cloakmask [lindex $s 1]
	set cloakfmt [lindex $s 2]
	nda set "gwcloaks/[ndaenc $cloaksrv]/[ndaenc $cloakmask]" $cloakfmt
	mtNotice mtopserv $f "Cloak added."
}

proc mtCloak:deltorserver {f to t} {
	if {![string match "*N*" [dict get $::mts nicks [string tolower $f] umode]]} {
		mtNotice mtopserv $f "You need to be a Network Administrator to use this command. If you are not opered, oper up and try again."
		return
	}
	set s [split $t " "]
	if {[llength $s] < 2} {mtNotice mtopserv $f "I, uh, I didn't see all the arguments I needed.";return}
	set cloaksrv [lindex $s 0]
	set cloakmask [lindex $s 1]

	nda set "gwcloaks/[ndaenc $cloaksrv]/[ndaenc $cloakmask]" ""
	mtNotice mtopserv $f "Cloak deleted."
}

proc mtCloak:docloak {u} {
	if {[string match "*t*" [dict get $::mts nicks [string tolower $u] umode]]} {mtPrivmsg mtopserv $::srvchan [format "Not cloaking user %s as they're already vhosted." $u];return}
	if {[string match "*S*" [dict get $::mts nicks [string tolower $u] umode]]} {mtPrivmsg mtopserv $::srvchan [format "Not cloaking user %s as they're a service." $u];return}
	set umsk [format "%s!%s@%s" $u [dict get $::mts nicks $u ident] [dict get $::mts nicks $u rhost]]
	set uip [dict get $::mts nicks $u nickip]
	set ucloakip [string tolower [string range [::md5::md5 -hex [::rc4::rc4 -key $::cloakkey $uip]] 0 15]]
	putcmdlog [format "%s cloakip is %s" $u $ucloakip]
	foreach {server cloaklist} [nda get "gwcloaks"] {
		if {[string match -nocase [ndadec $server] [dict get $::mts nicks $u serveron]]} {
			foreach {mask cloak} $cloaklist {
				set msk [ndadec $mask]
				if {[string match -nocase $msk $umsk]} {
					mtSetVhost mtOpServ $u [string map [list "%ucloakip" $ucloakip "%uip" [binToString $uip]] $cloak]
					putcmdlog "Setting $u vhost to [string map [list "%ucloakip" $ucloakip "%uip" [binToString $uip]] $cloak]"
					if {$msk != "*!*@*"} {return}
				}
			}
		}
	}
}
