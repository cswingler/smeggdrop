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
		return $result;
	}

	proc _secret_set args {
		log "Secret set invoked with $args";
		set ret [safe invokehidden set {*}$args];
		return $ret;
	}

	proc _secret_unset args {
		log "Secret unset invoked with $args";
		set ret [safe invokehidden unset {*}$args];
		return $ret;
	}
	
	# Pretty simple, this creates a 'safe' command
	# we can use for all future interpreter messing about
	_build_interp;

	# These are lists of commands to hide and replace with
	# an alias to this namespace, so they may be watched
	variable hidden_cmds [list \
		append dict info interp lappend lassign linsert \
		lreplace lset namespace proc rename set unset \
	];
	foreach cmd $hidden_cmds {
		safe hide $cmd;
		log "Setting cmd $cmd alias to safe::_secret_$cmd";
		safe alias $cmd safe::_secret_$cmd;
	}

	# Commands which are not allowed at all
	variable disallowed_cmds [list \
		chan eof fblocked fcopy fileevent flush gets \
		package pid read seek tell trace \
	];
	foreach cmd $disallowed_cmds {
		log "Hiding command $cmd";
		safe hide $cmd;
	}
}
