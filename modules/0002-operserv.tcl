#Assumes logger is loaded.

bind [dict get $::mts sock] msg mtopserv checkop mtOpServ:amIop

proc mtOpServ:amIop {f to t} {
	mtNotice mtOpServ $f [format "Your umodes are +%s" [dict get $::mts nicks [string tolower $f] umode]]
}
