namespace eval safe {

	variable command;   # Command to run
	variable caller;    # Who called it
	variable channel    # Which channel
	variable auth;      # Whether they are authed
	variable network;   # Which network they are on
	
	proc _build_interp {} {
		interp create -safe safe;
		safe recursionlimit 10;
	}

	proc run args {
		variable command;
		set result {};
		set change {};
		
		log "Running command";
		set start [clock clicks -milliseconds];
		lappend change "Starting execution at ${start}ms";

		set ret [catch {safe eval $command} result details];

		set execdone [clock clicks -milliseconds];
		lappend change "Beginning diff after [expr $execdone-$start]ms";

		if {$ret != 0} {
			set result [list "Error: $result\n$details"];
		}

		lappend change [rcs::diff];

		set done [clock clicks -milliseconds];
		lappend change "Finished diff after [expr $done-$execdone]ms";

		set result [list $result [join $change "\n"]];
		return $result;
	}

	# Pretty simple, this creates a 'safe' command
	# we can use for all future interpreter messing about
	_build_interp;

	# These are lists of commands to hide and replace with
	# an alias to the rcs namespace, so they may be watched
	# for changes to variables, procs, namespaces
	variable hidden_cmds [list \
		array append dict info lappend lassign \
		namespace global upvar proc rename set unset \
	];
	foreach cmd $hidden_cmds {
		safe hide $cmd;
		log "Setting cmd $cmd alias to rcs::_$cmd";
		safe alias $cmd rcs::_$cmd;
	}

	# Commands which are not allowed at all
	variable disallowed_cmds [list \
		chan eof fblocked fcopy fileevent flush gets \
		interp package pid puts read seek tell trace \
	];
	foreach cmd $disallowed_cmds {
		log "Hiding command $cmd";
		safe hide $cmd;
	}

	# Set existing variables and procs as protected
	foreach var [safe invokehidden info vars *] {
		lappend rcs::protected_vars     [rcs::full_name $var];
	}
	foreach proc [safe invokehidden info commands] {
		lappend rcs::protected_procs    [rcs::full_name $proc];
	}
}

# A global unknown handler checks for any undefined commands
# and permits them without filtering if an alias does not exist
proc unknown args {
	if {[regexp {^rcs::_(\w+)$} [lindex $args 0] match procname]} {
		set args [lrange $args 1 end];
		set ret [safe invokehidden $procname {*}$args];
		return $ret;
	} {
		error "Unknown: $args";
	}
}
