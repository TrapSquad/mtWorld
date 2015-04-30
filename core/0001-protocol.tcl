set mts [list]

proc hex2dec {largeHex} {
    set res 0
    foreach hexDigit [split $largeHex {}] {
        set new 0x$hexDigit
        set res [expr {16*$res + $new}]
    }
    return $res
};# MS @ wiki.tcl.tk

if {[info commands putdcc] != [list putdcc]} {
	proc putdcc {idx text} {
		puts $idx $text
	}
}

if {[info commands putcmdlog] != [list putcmdlog]} {
	proc putcmdlog {text} {
		puts -nonewline stdout "(command) "
		puts stdout $text
	}
}

proc IsServer {nick} {
	if {[string first $nick "."] != -1} {return 1} {return 0}
}

proc mtIrcMain {sck} {
	global mts
	if {[eof $sck]} {close $sck;return}
	gets $sck line
	set line [string trim $line "\r\n"]
	set one [string match "\[@:]*" $line]
	set line [string trimleft $line ":"]
	set gotsplitwhere [string first " :" $line]
	if {$gotsplitwhere==-1} {set comd [split $line " "]} {set comd [split [string range $line 0 [expr {$gotsplitwhere - 1}]] " "]}
	set payload [string range $line [expr {$gotsplitwhere + 2}] end]
	#putcmdlog $line
	# Well, um, we now have to support Unreal3.4-alpha*, so yoah
	switch -exact -- [lindex $comd $one] {
		"SERVER" {
			putcmdlog "We now know who we're directly linked to."
			dict set mts rname [lindex $comd 1]
		}
		"AO" - "NETINFO" {
			putdcc $sck $line
			putcmdlog "Received NETINFO, repeating back"
		}
		"ES" - "EOS" {
			if {[lindex $comd 0] == [dict get $::mts rname]} {
				putdcc $sck [format ":%s ES" [dict get $::mts name]]
				putcmdlog "Received EOS, EOSing back to the uplink"
				callbind $sck evnt - synched
			}
		}
		"," - "QUIT" {
			lset comd 0 [string tolower [lindex $comd 0]]
			foreach {k v} [dict get $::mts chans] {
				if {![dict exists $::mts chans $k nick [lindex $comd 0] onchan]} {continue}
				if {[dict get $::mts chans $k nick [lindex $comd 0] onchan] == "1"} {
					dict set mts chans $k nick [lindex $comd 0] uo ""
					dict set mts chans $k nick [lindex $comd 0] onchan 0
				}
			}
			dict set mts nicks [lindex $comd 0] [list]
			callbind $sck evnt - signoff [lindex $comd 0]
		}
		"." - "KILL" {
			lset comd 2 [string tolower [lindex $comd 2]]
			foreach {k v} [dict get $::mts chans] {
				if {![dict exists $::mts chans $k nick [lindex $comd 2] onchan]} {continue}
				if {[dict get $::mts chans $k nick [lindex $comd 2] onchan] == "1"} {
					dict set mts chans $k nick [lindex $comd 2] uo ""
					dict set mts chans $k nick [lindex $comd 2] onchan 0
				}
			}
			dict set mts nicks [lindex $comd 2] [list]
			callbind $sck evnt - signoff [lindex $comd 2]
		}
		"D" - "PART" {
			dict set mts chans [lindex $comd 2] nick [lindex $comd 0] onchan 0
			dict set mts chans [lindex $comd 2] nick [lindex $comd 0] uo ""
		}
		"&" - "NICK" {
			lset comd [expr {$one+1}] [string tolower [lindex $comd [expr {$one+1}]]]
			lset comd 0 [string tolower [lindex $comd 0]]
			if {$one == 1} {
				dict set mts nicks [lindex $comd 2] [dict get $::mts nicks [lindex $comd 0]]
				dict set mts nicks [lindex $comd 0] [list]
				foreach {k v} [dict get $::mts chans] {
					if {![dict exists $::mts chans $k nick [lindex $comd 0] onchan]} {continue}
					if {[dict get $v nick [lindex $comd 0] onchan] == "1"} {
						dict set mts chans $k nick [lindex $comd 2] uo [dict get $v nick [lindex $comd 0] uo]
						dict set mts chans $k nick [lindex $comd 2] onchan 1
					}
				}
				callbind $sck evnt - nickchg [lindex $comd 2] [lindex $comd 0]
			} {
				dict set mts nicks [lindex $comd 1] ident [lindex $comd 4]
				dict set mts nicks [lindex $comd 1] rhost [lindex $comd 5]
				dict set mts nicks [lindex $comd 1] serveron [lindex $comd 6]
				dict set mts nicks [lindex $comd 1] vhost [lindex $comd 9]
				dict set mts nicks [lindex $comd 1] suser [lindex $comd 7]
				if {"*" != [lindex $comd 10]} {dict set mts nicks [lindex $comd 1] nickip [binary decode base64 [lindex $comd 10]]} {dict set mts nicks [lindex $comd 1] nickip [binary decode hex 00000000]}
				dict set mts nicks [lindex $comd 1] umode [string range [lindex $comd 8] 1 end]
				callbind $sck evnt - signon [lindex $comd 1]
			}
		}
		"|" - "UMODE2" {
			lset comd 0 [string tolower [lindex $comd 0]]
			foreach {c} [split [lindex $comd 2] {}] {
				switch -exact -- $c {
					"+" {set state 1}
					"-" {set state 0}
					default {
						if {$state && $c != " "} {
							dict set mts nicks [lindex $comd 0] umode [format "%s%s" [dict get $::mts nicks [string tolower [lindex $comd 0]] umode] $c]
							callbind $sck umode - +$c [lindex $comd 0]
						} {
							dict set mts nicks [lindex $comd 0] umode [string map [list $c ""] [dict get $::mts nicks [string tolower [lindex $comd 0]] umode]]
							putcmdlog [dict get $::mts nicks [string tolower [lindex $comd 0]] umode]
							callbind $sck umode - -$c [lindex $comd 0]
						}
					}
				}
			}
		}
		"G" - "MODE" {
			lset comd 2 [string tolower [lindex $comd 2]]
			set addto 0
			foreach {c} [split [lindex $comd 3] {}] {
				switch -regexp -- $c {
					"\\+" {set state 1}
					"\\-" {set state 0}
					"\[beIqaohvlkL]" {
						incr addto
						lset comd 3+$addto [string tolower [lindex $comd 3+$addto]]
						if {$state && $c != " "} {
							switch -regexp -- $c {
								"\[qaohv]" {
									if {![dict exists mts chans [lindex $comd 2] nick [lindex $comd 3+$addto] uo]} {
										dict set dict set mts chans [lindex $comd 2] nick [lindex $comd 3+$addto] uo $c
									} {
										dict set mts chans [lindex $comd 2] nick [lindex $comd 3+$addto] uo [format "%s%s" $c [dict get $::mts chans [lindex $comd 2] nick [lindex $comd 3+$addto] uo]]
									}
								}
							}
							callbind $sck mode - +$c [lindex $comd 2] [lindex $comd 3+$addto]
							callbind $sck evnt - mode +$c [lindex $comd 2] [lindex $comd 3+$addto]
						} {
							switch -regexp -- $c {
								"\[qaohv]" {
									dict set mts chans [lindex $comd 2] nick [lindex $comd 3+$addto] uo [string map [list $c ""] [dict get $::mts chans [lindex $comd 2] nick [lindex $comd 3+$addto] uo]]
								}
							}
							callbind $sck mode - -$c [lindex $comd 2] [lindex $comd 3+$addto]
							callbind $sck evnt - mode -$c [lindex $comd 2] [lindex $comd 3+$addto]
						}
					}
				}
			}
		}
		"C" - "JOIN" {
			dict set mts chans [lindex $comd 2] nick [lindex $comd 0] onchan 1
			dict set mts chans [lindex $comd 2] nick [lindex $comd 0] uo ""
		}
		"~" - "SJOIN" {
			lset comd 3 [string tolower [lindex $comd 3]]
			if {[dict exists $::mts chans [lindex $comd 3] ts]} {
				if {[lindex $comd 2] < [dict get $::mts chans [lindex $comd 3] ts]} {
					putcmdlog "Uh, I'm not sure this is supposed to happen. Retriggering synched bind to ask all modules to reop their bots."
					callbind $sck evnt - synched
				}
			}
			dict set mts chans [lindex $comd 3] ts [lindex $comd 2]
			putcmdlog [join [split $payload " "] " "]
			set bei 0
			foreach {name} [split $payload " "] {
				if {[string index $name 0] == "&"} {set bei 1}
				if {[string index $name 0] == "\""} {set bei 1}
				if {[string index $name 0] == "'"} {set bei 1}
				if {$bei == 0} {
					set ums 0
					set nick ""
					set uo ""
					foreach {c} [split $name {}] {
						if {$c != "*" && $c != "~" && $c != "@" && $c != "%" && $c != "+"} {set ums 1}
						if {$ums} {append nick $c} {append uo [string map [list "*" "q" "~" "a" "@" "o" "%" "h" "+" "v"] $c]}
					}
					if {$nick == ""} {continue}
					if {$nick == "{}"} {continue}
					set nick [string tolower $nick]
					putcmdlog [format "User %s joined to %s +%s" $nick [lindex $comd 3] $uo]
					callbind $sck join - [lindex $comd 3] $nick [lindex $comd 3]
					callbind $sck join - - $nick [lindex $comd 3]
					foreach {uoc} [split $uo {}] {
						callbind $sck mode - +$uoc [lindex $comd 3] $nick
					}
					dict set mts chans [lindex $comd 3] nick $nick uo $uo
					dict set mts chans [lindex $comd 3] nick $nick onchan 1
				} {
					set bmask [string range $name 1 end]
					set mt [string map [list "&" "b" "\"" "e" "'" "I"] [string index $name 0]]
					callbind $sck mode - +$mt [lindex $comd 3] $bmask
				}
			}
		}
		"!" - "PRIVMSG" {
			putcmdlog $line
			if {[string index [lindex $comd 2] 0] == "#"} {
				set msg [split $payload " "]
				set rest [join [lrange $msg 1 end] " "]
				callbind $sck pub - [string tolower [lindex $msg 0]] [lindex $comd 0] [lindex $comd 2] $rest
			} {
				set msg [split $payload " "]
				set rest [join [lrange $msg 1 end] " "]
				callbind $sck msg [string tolower [lindex $comd 2]] [string tolower [lindex $msg 0]] [lindex $comd 0] [lindex $comd 2] $rest
			}
		}
		"8" - "PING" {
			putdcc $sck [format "9 %s %s" [dict get $::mts name] [lindex $comd 1]]
		}
	}
}

proc mtIrcConnect {name pass addr port {gecos "mtServices"}} {
	global mts
	dict set mts sock [set sck [connect $addr $port mtIrcMain]]
	dict set mts name $name
	putdcc $sck [format "PASS %s" $pass]
	putdcc $sck "PROTOCTL SJOIN SJOIN2 SJ3 TKLEXT VL NICKv2 VHP TOKEN ESVID UMODE2 NICKIP"
	putdcc $sck [format "SERVER %s 1 :U2311-Eh %s" $name $gecos]
}

proc mtSend {data} {
	global mts
	putdcc [dict get $::mts sock] $data
}

proc mtNewNick {n uh h g} {
	mtSend [format ":%s SQLINE %s :Reserved for %s (if this is in error, ask for help from the opers)" [dict get $::mts name] $n [dict get $::mts name]]
	mtSend [format "NICK %s 1 100 %s %s %s 0 +HISoqi %s :%s" $n $uh $h [dict get $::mts name] $h $g]
}

proc mtPrivmsg {from targ msg} {
	mtSend [format ":%s PRIVMSG %s :%s" $from $targ $msg]
}

proc mtNotice {from targ msg} {
	mtSend [format ":%s NOTICE %s :%s" $from $targ $msg]
}

proc mtPart {from targ msg} {
	mtSend [format ":%s PART %s :%s" $from $targ $msg]
}

proc mtSetAcct {from targ msg} {
	global mts
	mtSend [format ":%s SVSMODE %s +d %s" $from $targ $msg]
	dict set mts nicks [string tolower $targ] suser $msg
}

proc mtSetVhost {from targ msg} {
	global mts
	mtSend [format ":%s CHGHOST %s %s" $from $targ $msg]
	dict set mts nicks [string tolower $targ] vhost $msg
}

proc mtSetRhost {from targ} {
	mtSend [format ":%s SVS2MODE %s -xt" $from $targ $msg]
}

proc mtOperUp {from targ oflags} {
	global mts
	mtSend [format ":%s SVSO %s +%s" $from $targ $oflags]
	mtSend [format ":%s SVS2SNO %s +%s" $from $targ cF]
	set opmodes ""
	if {[string match "*N*" $oflags]} {append opmodes N}
	if {[string match "*A*" $oflags]} {append opmodes A}
	if {[string match "*a*" $oflags]} {append opmodes a}
	if {[string match "*C*" $oflags]} {append opmodes C}
	if {[string match "*O*" $oflags]} {append opmodes owgs}
	if {[string match "*h*" $oflags]} {append opmodes h}
	if {[string match "*W*" $oflags]} {append opmodes W}
	mtSend [format ":%s SVS2MODE %s +%s" $from $targ $opmodes]
	dict set mts nicks [string tolower $targ] umode [format "%s%s" [dict get $::mts nicks [string tolower $targ] umode] $opmodes]
}

proc mtJoin {from targ modes} {
	if {![dict exists $::mts chans [string tolower $targ] ts]} {
		global mts
		dict set mts chans [string tolower $targ] ts [clock format [clock seconds] -format "%s"]
	}
	mtSend [format ":%s SJOIN %s %s :%s%s" [dict get $::mts name] [dict get $::mts chans [string tolower $targ] ts] $targ [string map [list "q" "*" "a" "~" "o" "@" "h" "%" "v" "+"] $modes] $from]
	putcmdlog [format ":%s SJOIN %s %s :%s%s" [dict get $::mts name] [dict get $::mts chans [string tolower $targ] ts] $targ [string map [list "q" "*" "a" "~" "o" "@" "h" "%" "v" "+"] $modes] $from]
	dict set mts chans [string tolower $targ] nick $from uo $modes
}
