#Assumes logger is loaded.

bind [dict get $::mts sock] msg [string tolower $::opsrvnick] checkop mtOpServ:amIop
bind [dict get $::mts sock] msg [string tolower $::opsrvnick] oper mtOpServ:oper
bind [dict get $::mts sock] msg [string tolower $::opsrvnick] sanick mtOpServ:sanick
bind [dict get $::mts sock] msg [string tolower $::opsrvnick] help mtOpServ:help

proc mtOpServ:amIop {f to t} {
	mtNotice $::opsrvnick $f [format "Your umodes are +%s" [dict get $::mts nicks [string tolower $f] umode]]
}

proc mtOpServ:oper {f to t} {
	set comd [split $t " "]
	if {![string match "*N*" [dict get $::mts nicks [string tolower $f] umode]] && [string tolower [lindex $comd 0]] != "login" && [string tolower [lindex $comd 0]] != "help"} {
		mtNotice $::opsrvnick $f "Access forbidden."
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
			mtNotice $::opsrvnick $f "Oline added or password & flags changed for existing oline."
		}
		"m" - "mo" - "mod" - "modi" - "modif" - "modify" {
			set login [lindex $comd 1]
			set oflags [lindex $comd 2]
			nda set "olines/[ndaenc $login]/oflags" $oflags
			nda set "olines/[ndaenc $login]/active" 1
			mtNotice $::opsrvnick $f "Oline modified."
		}
		"g" - "ge" - "get" {
			mtNotice $::opsrvnick $f "Beginning O:line list:"
			foreach {li data} [nda get "olines"] {
				set loi [ndadec $li]
				set oflgs [dict get $data oflags]
				set isable [dict get $data active]
				set msg [format "  O:line %s has flags +%s" $loi $oflgs]
				if {$isable} {mtNotice $::opsrvnick $f $msg}
			}
			mtNotice $::opsrvnick $f "Ending O:line list."
		}
		"d" - "de" - "del" - "dele" - "delet" - "delete" {
			set login [lindex $comd 1]
			nda set "olines/[ndaenc $login]/pw" ""
			nda set "olines/[ndaenc $login]/oflags" ""
			nda set "olines/[ndaenc $login]/active" 0
			mtNotice $::opsrvnick $f "Oline deleted."
		}
		"l" - "lo" - "log" - "logi" - "login" {
			if {[::sha1::sha1 -hex [lindex $comd 2]] == [nda get "olines/[ndaenc [lindex $comd 1]]/pw"]} {
				mtOperUp [string tolower $::opsrvnick] $f [nda get "olines/[ndaenc [lindex $comd 1]]/oflags"]
			} {
				mtNotice $::opsrvnick $f "No."
			}
		}
		default {
			mtNotice $::opsrvnick $f "Help:"
			mtNotice $::opsrvnick $f " OPER ADD login password oflags"
			mtNotice $::opsrvnick $f "  Add a new oper to mtWorld. (Requires umode +N)"
			mtNotice $::opsrvnick $f " OPER DEL login"
			mtNotice $::opsrvnick $f "  Delete an oper from mtWorld. (Requires umode +N)"
			mtNotice $::opsrvnick $f " OPER MODIFY login new-oflags"
			mtNotice $::opsrvnick $f "  Modify an mtWorld oper. (Requires umode +N)"
			mtNotice $::opsrvnick $f " OPER LOGIN login password"
			mtNotice $::opsrvnick $f "  Identify to your mtWorld O:line."
			mtNotice $::opsrvnick $f " OPER GET"
			mtNotice $::opsrvnick $f "  Get a list of olines. (Requires umode +N)"
			mtNotice $::opsrvnick $f "O:lines in mtWorld SVSO you if successfully authenticated for."
			mtNotice $::opsrvnick $f "The oflags parameter is equivalent to the Unreal oper flags (/helpop ?oflags)"
		}
	}
}


proc mtOpServ:sanick {f to t} {
	set comd [split $t " "]
	if {![string match "*N*" [dict get $::mts nicks [string tolower $f] umode]]} {
		mtNotice $::opsrvnick $f "Access forbidden."
		return
	}
	set ts [clock format [clock seconds] -format %s]
	if {""==[lindex $comd 0]} {mtNotice $::opsrvnick $f "Missing parameter.";return}
	if {""==[lindex $comd 1]} {mtNotice $::opsrvnick $f "Missing parameter.";return}
	mtSend [format ":%s e %s %s :%s" $::opsrvnick [lindex $comd 0] [lindex $comd 1] $ts]
}

proc mtOpServ:help {f to t} {
	set fp [open ./0002-operserv.help r]
	while {![eof $fp]} {
		mtNotice $::opsrvnick $f [gets $fp]
	}
	close $fp
}
