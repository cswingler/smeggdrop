namespace eval rcs {
	# Revision Control System for tcl including a bunch
	# of safety stuff for shittybot
	# TODO: Strip this out so it does rcs only

	# Changes made
	# TODO: Change to array
	variable changes        {};
	# These variables store lists or arrays referring to
	# modifications in the current tcl execution
	variable var_check;
	array set var_check {};
	variable var_add         {};
	variable var_del         {};
	variable var_change      {};

	variable proc_add        {};
	variable proc_del        {};
	variable proc_change     {};

	variable namespace_add   {};
	variable namespace_del   {};
	
	# Diff should collect the list of changes and check
	# any variables that are listed to produce a state delta
	# to pass to other interpreters
	proc diff {} {
		variable var_check;
		variable changes;

		log "Running diff: [array get var_check]";

		foreach var [array names var_check] {
			log "Checking variable $var";
			var_changed $var $var_check($var);
		}

		set changed $changes;
		diff_reset;
		return $changed;
	}

	proc diff_reset {} {
		variable changes;
		variable var_check;
		variable var_add;
		variable var_del;
		variable var_change;

		variable proc_add;
		variable proc_del;
		variable proc_change;

		variable namespace_add;
		variable namespace_del;

		array set var_check {};
		set var_add         {};
		set var_del         {};
		set var_change      {};
		set proc_add        {};
		set proc_del        {};
		set proc_change     {};
		set namespace_add   {};
		set namespace_del   {};
		set changes         {};
	}

	proc array_deleted {name} {
		variable changes;

		lappend changes "Deleted array variable $name";
	}

	proc var_changed {name {old {}}} {
		variable changes;

		if {[safe invokehidden info exists $name]} {
			set new [safe invokehidden set $name];
			if {$old ne {} && $old ne $new} {
				log "Changed $name from $old to $new";
				lappend changes "Changed $name from $old to $new";
			} elseif {$old eq {}} {
				log "Created $name variable: $new";
				lappend changes "Created $name variable: $new";
			}
		} {
			log "Variable $name deleted";
			lappend changes "Variable $name deleted";
		}
	}

	# Add the variable and its current contents to the
	# list of variables to check after execution
	proc check_var {name} {
		variable var_check;

		set body {};
		if {[safe invokehidden info exists $name]} {
			set body [safe invokehidden set $name];
		}

		if {![info exists var_check($name)]} {
			log "Adding $name to var_check";
			set var_check($name) $body;
		}
	}

	# Tracking the variable assignments for global
	# and upvar is likely to be too much work for us
	# and we're only interested in global or specifically
	# referenced namespace. For this reason, if global
	# or upvar refers to these variables, we check their
	# value at the end of execution compared to when
	# they were first referred to.
	# TODO: Investigate race condition between global
	# sets and the check at the end, should be ok.
	# TODO: Improve matching quality to the point we can
	# fully track variables in stack frames so no post-exec
	# checking is needed
	proc _global args {
		log "Global called with args: $args";

		set ret {};
		foreach var $args {
			# Prepend a global namespace if unqualified
			if {![regexp {^::} $var]} {set var "::$var"}
			# Fetch the current contents of the variable

			# Add it to the list of variables to check
			check_var $var;

			# If the variable isn't already being checked
			# add it to the list
			append ret [safe invokehidden global $var];
		}
		log "Check: [array get var_check]";
		return $ret;
	}

	# Upvar allows you to link a lexical variable to one in a
	# different stack. If the level is '#0' then this refers
	# to a global variable so this should be tracked. Equally
	# if the level is equal to the current stack frame level
	# I believe this will refer to a global.
	proc _upvar args {
		log "Upvar called with args; $args";

		set level   [lindex $args 0];
		set ret     {};

		# Detect level
		if {[regexp {^(#?\d+)$} $level matches leveln]} {
			log "Upvar detected with level of $leveln";
			set level $leveln;
			set args [lreplace $args 0 0];
		} {
			log "Upvar detected with no level";
			set level 1;
		}

		# Check to see if this is a global we are interested in
		if {$level eq "#0" || $level == [safe invokehidden info level]} {
			# Iterate over instances of upvar and mark them
			while {[llength $args]} {
				set vars    [lrange $args 0 1];
				set varname [lindex $vars 0];
				set args    [lreplace $args 0 1];

				# Global variable
				if {[safe invokehidden info exists $varname]} {
					check_var $varname;
					append ret [safe invokehidden upvar $level {*}$vars];
				} {
					safe eval "error \"can't read \\\"$varname\\\": no such variable\"";
				}
			}
		}
		return $ret;
	}
	
	proc _lappend args {
		log "lappend called with args $args";

		set varname [lindex $args 0];
		set varbody {};

		# Get the interpreter's current stack level and determine
		# whether unqualified variables are global are not.
		set level [safe invokehidden info level];
		log "Stack level: $level";
		if {$level != 0 && ![regexp {::} $varname]} {
			# We should just pass this through as it is a lexical
			# variable.
			set ret [safe invokehidden lappend {*}$args];
			return $ret;
		}

		# Check if it already exists
		if {[safe invokehidden info exists $varname]} {
			# Variable exists, get its contents
			set varbody [safe invokehidden set $varname];
		}

		set ret [safe invokehidden lappend {*}$args];
		var_changed $varname $varbody;
		return $ret;
	}

	proc _set args {
		log "Set called with args: $args";

		set varname [lindex $args 0];
		set varval  {};

		# Get the interpreter's current stack level and determine
		# whether unqualified variables are global are not.
		set level [safe invokehidden info level];
		log "Stack level: $level";
		if {$level != 0 && ![regexp {::} $varname]} {
			# We should just pass this through as it is a lexical
			# variable.
			set ret [safe invokehidden set {*}$args];
			return $ret;
		}

		if {[safe invokehidden info exists $varname]} {
			# If the variable already exists, get the current value
			set varval [safe invokehidden set $varname];
		}

		set ret [safe invokehidden set {*}$args];
		var_changed $varname $varval;
		return $ret;
	}

	proc _unset args {
		log "Secret unset invoked with $args";

		set ret {};
		foreach var $args {
			log "Unsetting $var";
			if {[safe invokehidden array exists $var]} {
				# We delete every array element so we need to generate
				# events for this
				foreach key [safe invokehidden array names $var] {
					log "Array key $var ($key) $var\($key\)";
					set varbody [safe invokehidden set "$var\($key\)"];
					# TODO: ugly, fix plz
					safe invokehidden unset "$var\($key\)";
					var_changed "$var\($key\)" $varbody;
				}
				array_deleted $var;
			}
			append ret [safe invokehidden unset $var];
		}
		return $ret;
	}

	proc _info args {
		log_debug{"Info called with $args"};
		if {[lindex $args 0] ne "hostname"} {
			set ret [safe invokehidden info {*}$args];
			return $ret;
		}
	}
}
