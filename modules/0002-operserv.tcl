#Assumes logger is loaded.

bind [dict get $::mts sock] msg mtopserv checkop mtOpServ:amIop
bind [dict get $::mts sock] msg mtopserv oper mtOpServ:oper

proc mtOpServ:amIop {f to t} {
	mtNotice mtOpServ $f [format "Your umodes are +%s" [dict get $::mts nicks [string tolower $f] umode]]
}

proc mtOpServ:oper {f to t} {
	set comd [split $t " "]
	if {![string match "*N*" [dict get $::mts nicks [string tolower $f] umode]] && [string tolower [lindex $comd 0]] != "login" && [string tolower [lindex $comd 0]] != "help"} {
		mtNotice mtOpServ $f "Access forbidden."
		return
	}
	switch -nocase -- [lindex $comd 0] {
		"a" - "ad" - "add" {
			set login [lindex $comd 1]
			set password [lindex $comd 2]
			set oflags [lindex $comd 3]
			nda set "olines/[ndaenc $login]/pw" [::sha1::sha1 -hex $password]
			nda set "olines/[ndaenc $login]/oflags" $oflags
			nda set "olines/[ndaenc $login]/active" 1
			mtNotice mtOpServ $f "Oline added or password & flags changed for existing oline."
		}
		"m" - "mo" - "mod" - "modi" - "modif" - "modify" {
			set login [lindex $comd 1]
			set oflags [lindex $comd 2]
			nda set "olines/[ndaenc $login]/oflags" $oflags
			nda set "olines/[ndaenc $login]/active" 1
			mtNotice mtOpServ $f "Oline modified."
		}
		"g" - "ge" - "get" {
			mtNotice mtOpServ $f "Beginning O:line list:"
			foreach {li data} [nda get "olines"] {
				set loi [ndadec $li]
				set oflgs [dict get $data oflags]
				set isable [dict get $data active]
				set msg [format "  O:line %s has flags +%s" $loi $oflgs]
				if {$isable} {mtNotice mtOpServ $f $msg}
			}
			mtNotice mtOpServ $f "Ending O:line list."
		}
		"d" - "de" - "del" - "dele" - "delet" - "delete" {
			set login [lindex $comd 1]
			nda set "olines/[ndaenc $login]/pw" ""
			nda set "olines/[ndaenc $login]/oflags" ""
			nda set "olines/[ndaenc $login]/active" 0
			mtNotice mtOpServ $f "Oline deleted."
		}
		"l" - "lo" - "log" - "logi" - "login" {
			if {[::sha1::sha1 -hex [lindex $comd 2]] == [nda get "olines/[ndaenc [lindex $comd 1]]/pw"]} {
				mtOperUp mtOpServ $f [nda get "olines/[ndaenc [lindex $comd 1]]/oflags"]
			} {
				mtNotice mtOpServ $f "No."
			}
		}
		default {
			mtNotice mtOpServ $f "Help:"
			mtNotice mtOpServ $f " OPER ADD login password oflags"
			mtNotice mtOpServ $f "  Add a new oper to mtWorld. (Requires umode +N)"
			mtNotice mtOpServ $f " OPER DEL login"
			mtNotice mtOpServ $f "  Delete an oper from mtWorld. (Requires umode +N)"
			mtNotice mtOpServ $f " OPER MODIFY login new-oflags"
			mtNotice mtOpServ $f "  Modify an mtWorld oper. (Requires umode +N)"
			mtNotice mtOpServ $f " OPER LOGIN login password"
			mtNotice mtOpServ $f "  Identify to your mtWorld O:line."
			mtNotice mtOpServ $f " OPER GET"
			mtNotice mtOpServ $f "  Get a list of olines. (Requires umode +N)"
			mtNotice mtOpServ $f "O:lines in mtWorld SVSO you if successfully authenticated for."
			mtNotice mtOpServ $f "The oflags parameter is equivalent to the Unreal oper flags (/helpop ?oflags)"
		}
	}
}
