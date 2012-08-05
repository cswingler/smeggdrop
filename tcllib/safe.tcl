namespace eval safe {

	variable command;   # Command to run
	variable caller;    # Who called it
	variable channel    # Which channel
	variable auth;      # Whether they are authed
	variable network;   # Which network they are on
	
	proc _build_interp {} {
		interp create -safe safe
	}

	proc run args {
		variable command;
		set result [safe eval $command];
		# TODO: Uncomment below
		# set change [rcs::diff];
		# log "Change is: $change"
		return $result;
	}

	proc test args {
		log [namespace current]
		log [uplevel namespace current]
		log [info vars]
		log [info vars ::safe]
	}
	# Pretty simple, this creates a 'safe' command
	# we can use for all future interpreter messing about
	_build_interp;
	safe alias test safe::test;

	# These are lists of commands to hide and replace with
	# an alias to this namespace, so they may be watched
	variable hidden_cmds [list \
		array append dict info interp lappend lassign \
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
		package pid puts read seek tell trace \
	];
	foreach cmd $disallowed_cmds {
		log "Hiding command $cmd";
		safe hide $cmd;
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
		return "Unknown: $args";
	}
}
