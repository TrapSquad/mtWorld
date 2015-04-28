if {![info exists ::quotenick]} {
	putcmdlog "You need to provide a quotenick in services.conf."
	exit
}

mtNewNick $::quotenick quote services. "Quote Services"

bind [dict get $::mts sock] evnt - synched mtQS:synched
proc mtQS:synched {} {
	foreach {chan is} [nda get "quoteserv/regchan"] {
		if {1!=$is} {continue}
		set dchan [ndadec $chan]
		mtJoin $::quotenick $dchan ao
	}
}
bind [dict get $::mts sock] request "q" - quoteservjoin
bind [dict get $::mts sock] request "quoteserv" "-" quoteservjoin
bind [dict get $::mts sock] pub "-" "!quote" quoteservdo
bind [dict get $::mts sock] pub "-" "!q" quoteservdo
bind [dict get $::mts sock] msg $::quotenick request mtQS:request
bind [dict get $::mts sock] msg $::quotenick delete mtQS:delete

proc mtQS:request {f to t} {
	set f [string tolower $f]
	set chan [lindex [split $t " "] 0]
	set chan [string tolower $chan]
	set ndacname [string map {/ [} [::base64::encode [string tolower $chan]]]
	set cando 0
	if {[dict exists $::mts chans $chan nick $f uo]} {
		if {[string first "o" [dict get $::mts chans $chan nick $f uo]] != -1} {set cando 1}
		if {[string first "a" [dict get $::mts chans $chan nick $f uo]] != -1} {set cando 1}
		if {[string first "q" [dict get $::mts chans $chan nick $f uo]] != -1} {set cando 1}
	}
	if {!$cando} {mtNotice $::quotenick $f "No.";return}
	mtJoin $::quotenick $chan ao
	mtPrivmsg $::quotenick $chan [format "\[\002Quotes\002\] I was requested to join this channel by %s" $f]
	nda set "quoteserv/regchan/$ndacname" 1
}

proc mtQS:delete {f to t} {
	set f [string tolower $f]
	set chan [lindex [split $t " "] 0]
	set chan [string tolower $chan]
	set ndacname [string map {/ [} [::base64::encode [string tolower $chan]]]
	set cando 0
	if {[dict exists $::mts chans $chan nick $f uo]} {
		if {[string first "o" [dict get $::mts chans $chan nick $f uo]] != -1} {set cando 1}
		if {[string first "a" [dict get $::mts chans $chan nick $f uo]] != -1} {set cando 1}
		if {[string first "q" [dict get $::mts chans $chan nick $f uo]] != -1} {set cando 1}
	}
	if {!$cando} {mtNotice $::quotenick $f "No.";return}
	mtPrivmsg $::quotenick $chan [format "\[\002Quotes\002\] I was requested to part this channel by %s" $f]
	mtPart $::quotenick $chan "Radar contact lost."
	nda set "quoteserv/regchan/$ndacname" 0
}

proc quoteservjoin {chan msg} {
	set ndacname [string map {/ [} [::base64::encode [string tolower $chan]]]
	mtJoin $::quotenick $chan ao
	nda set "quoteserv/regchan/$ndacname" 1
}

proc quoteservenabled {chan} {
	set ndacname [string map {/ [} [::base64::encode [string tolower $chan]]]
	return [nda get "quoteserv/regchan/$ndacname"]
}

proc quoteservdo {from chan msg} {
	set ndacname [string map {/ [} [::base64::encode [string tolower $chan]]]
	if {![quoteservenabled $chan]} {return}
	# $::quotenick isn't in channel, no need to check quotes
	set subcmd [lindex [split $msg " "] 0]
	set para [lrange [split $msg " "] 1 end]
	switch -nocase -glob -- $subcmd {
		"sea*" {
			set ptn "*[join $para " "]*"
			set qts [quotesearch $chan $ptn]
			if {[llength $qts]} {mtPrivmsg $::quotenick $chan "\[\002Quotes\002\] Found quotes numbered #[join $qts ",#"]"} {
				mtPrivmsg $::quotenick $chan "\[\002Quotes\002\] No quotes found for pattern"
			}
		}
		"vi*1st*ma*" {
			set ptn "*[join $para " "]*"
			set qts [quotesearch $chan $ptn]
			if {[llength $qts]} {set qtn [lindex $qts 0];mtPrivmsg $::quotenick $chan "\[\002Quotes\002\] Quote number #$qtn:";mtPrivmsg $::quotenick $chan "\[\002Quotes\002\] [nda get "quoteserv/quotes/$ndacname/$qtn"]"} {
				mtPrivmsg $::quotenick $chan "\[\002Quotes\002\] No quotes found for pattern"
			}
		}
		"ad*" {
			set qt [join $para " "]
			set qtn [expr {([llength [nda get "quoteserv/quotes/$ndacname"]]/2)+3}]
			nda set "quoteserv/quotes/$ndacname/$qtn" $qt
			mtPrivmsg $::quotenick $chan "\[\002Quotes\002\] Added quote number #$qtn to database."
		}
		"de*" {
			set qtn "[lindex $para 0]"
			if {![string is integer $qtn]} {mtPrivmsg $::quotenick $chan "\[\002Quotes\002\] Please use a valid integer (without the #)"}
			if {150>[nda get "regchan/$ndacname/levels/[string tolower [tnda get "login/$::netname([dict get $::mts sock])/$from"]]"]} {mtPrivmsg $::quotenick $chan "\[\002Quotes\002\] Check your privilege."}
			nda set "quoteserv/quotes/$ndacname/$qtn" ""
			mtPrivmsg $::quotenick $chan "\[\002Quotes\002\] Blanked quote number #$qtn in database."
		}
		"vi*" {
			set qtn "[lindex $para 0]"
			if {![string is integer $qtn]} {mtPrivmsg $::quotenick $chan "\[\002Quotes\002\] Please use a valid integer (without the #)"}
			set qt [nda get "quoteserv/quotes/$ndacname/$qtn"]
			if {$qt != ""} {
				mtPrivmsg $::quotenick $chan "\[\002Quotes\002\] Quote number #$qtn:"
				mtPrivmsg $::quotenick $chan "\[\002Quotes\002\] $qt"
			}
		}
		"he*" {
			set helpfile {             ---- Quotes Help ----
!quote search - Search for quotes matching
!quote view1stmatch - Search for quotes matching and view first matching quote.
!quote view - View quote
!quote add - Add quote.
!quote del - Delete quote. Requires halfops or above.
End of help for Q.}
			foreach {helpline} [split $helpfile "\r\n"] {
				mtNotice $::quotenick $from $helpline
			}
		}
	}
}

proc quotesearch {chan pattern} {
	set ndacname [string map {/ [} [::base64::encode [string tolower $chan]]]
	set ret [list]
	foreach {qnum qvalue} [nda get "quoteserv/quotes/$ndacname"] {
		if {[string match -nocase $pattern $qvalue]} {lappend ret $qnum}
	}
	return $ret
}

