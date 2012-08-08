namespace eval rcs {
	# Revision Control System for tcl including a bunch
	# of safety stuff for shittybot
	# TODO: Strip this out so it does rcs only

	# Changes made to variables and procs etc
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
	
	variable protected_procs {};
	variable protected_vars  {};
	variable protected_namespaces {};

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

		unset var_check;
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

	proc stack_check {name lambda {args {}}} {
		log "Checking stack level of $name";

		# Get the interpreter's current stack level and determine
		# whether unqualified variables are global are not.
		set level [safe invokehidden info level];
		log "Stack level: $level";
		if {$level != 0 && ![regexp {::} $name]} {
			# We should just pass this through as it is a lexical
			# variable.
			return [apply $lambda {*}$args];
		}
	}

	proc var_name {name} {
		# Make the variable name fully qualified
		if {![regexp {^::} $name]} {
			set name "::$name";
		}
		return $name;
	}

	proc proc_changed {name {old {}} {new {}}} {
		variable changes;

		if {$name eq {}} { return; }

		if {$old ne {} && $new ne {}} {
			log "Changed proc $name from $old to $new";
			lappend changes "Changed proc $name from $old to $new";
		} elseif {$new ne {}} {
			log "Created proc $name: $new";
			lappend changes "Created proc $name: $new";
		} {
			log "Deleted proc $name";
			lappend changes "Deleted proc $name";
		}
	}

	proc var_changed {name lambda {args {}}} {
		variable changes;
		log "Checking variable $name with values $args";

		set old {};
		set new {};

		if {[safe invokehidden info exists $name]} {
			set old [safe invokehidden set $name];
		}

		set ret [apply $lambda {*}$args];

		if {[safe invokehidden info exists $name]} {
			set new [safe invokehidden set $name];
		}

		if {$old eq $new} {
			return;
		} elseif {$old ne {} && $new ne {}} {
			lappend changes "Variable $name changed from $old to $new";
		} elseif {$old ne {}} {
			lappend changes "Variable $name deleted";
		} else {
			lappend changes "Variable $name created as $new";
		}

		return $ret;
	}

	# Determine what the lambda function changes
	proc arr_changed {name lambda {args {}}} {
		variable changes;
		log "Checking array $name with values $args";

		set old {};
		set new {};
		
		if {[safe invokehidden array exists $name]} {
			set old [safe invokehidden array get $name];
		}

		set ret [apply $lambda {*}$args];

		if {[safe invokehidden array exists $name]} {
			set new [safe invokehidden array get $name];
		}
		
		if {$old eq $new} {
			return;
		} elseif {$old ne {} && $new ne {}} {
			lappend changes "Array $name changed from $old to $new";
		} elseif {$old ne {}} {
			lappend changes "Array $name deleted";
		} else {
			lappend changes "Array $name created as $new";
		}

		return $ret;
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

	proc _array args {
		log "array called with args $args";

		set cmd     [lindex $args 0];
		set name    [lindex $args 1];
		set lambda  {x {safe invokehidden array {*}$x}};

		switch $cmd {
			"set" {
				if {[set ret [stack_check $name $lambda $args]] ne {}} {
					return $ret;
				} {
					set name [var_name $name];
					return [arr_changed     $name $lambda $args];
				}
			}
			"unset" {
				if {[set ret [stack_check $name $lambda $args]] ne {}} {
					return $ret;
				} {
					set name [var_name $name];
					return [arr_changed     $name $lambda $args];
				}
			}
			default {
				return [safe invokehidden array {*}$args];
			}
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
			log "Got global variables to test";
			while {[llength $args]} {
				set vars    [lrange $args 0 1];
				set varname [lindex $vars 0];
				set args    [lreplace $args 0 1];
				log "Vars: $vars";
				log "Varname: $varname";

				# Global variable
				if {[safe eval "uplevel $level {info exists $varname}"]} {
					check_var $varname;
					append ret [safe invokehidden upvar $level {*}$vars];
				} {
					safe eval error "can't read {$varname}: no such variable";
				}
			}
		}
		return $ret;
	}

	proc _proc args {
		variable protected_procs;
		log "Proc called with args $args";

		set procname    [lindex $args 0];
		if {[lsearch -exact $protected_procs $procname] != -1} {
			safe eval "error {Proc $procname is protected}";
			return;
		}

		set oldargs {};
		set oldbody {};
		set newargs {};
		set newbody {};
		if {[safe eval {lsearch -exact [info procs]} "{$procname}"] != -1} {
			set oldargs [safe invokehidden info args $procname];
			set oldbody [safe invokehidden info body $procname];
		}
		set ret [safe invokehidden proc {*}$args];
		if {[safe eval {lsearch -exact [info procs]} "{$procname}"] != -1} {
			set newargs [safe invokehidden info args $procname];
			set newbody [safe invokehidden info body $procname];
		}
		proc_changed $procname [list $oldargs $oldbody] [list $newargs $newbody];
		return $ret;
	}
	
	proc _rename args {
		variable protected_procs;
		log "Rename called with args $args";

		set old [lindex $args 0];
		set new [lindex $args 1];

		if {[lsearch -exact $protected_procs $old]  != -1} {
			safe eval "error {Proc $old is protected}";
			return;
		}

		if {[safe eval {lsearch -exact [info procs]} "{$old}"] == -1} {
			safe eval "error {Proc $old doesn't exist?}";
			return;
		}

		set oldargs {};
		set oldbody {};
		set newargs {};
		set newbody {};
		if {[safe eval {lsearch -exact [info procs]} "{$old}"] != -1} {
			set oldargs [safe invokehidden info args $old];
			set oldbody [safe invokehidden info body $old];
		}
		proc_changed $old [list $oldargs $oldbody] [list $newargs $newbody];

		if {[safe eval {lsearch -exact [info procs]} "{$new}"] != -1} {
			set oldargs [safe invokehidden info args $new];
			set oldbody [safe invokehidden info body $new];
		} {
			set oldargs {};
			set oldbody {};
		}

		set ret [safe invokehidden rename {*}$args];

		if {[safe eval {lsearch -exact [info procs]} "{$new}"] != -1} {
			set newargs [safe invokehidden info args $new];
			set newbody [safe invokehidden info body $new];
		}
		
		proc_changed $new [list $oldargs $oldbody] [list $newargs $newbody];
		return $ret;
	}
	
	proc _lappend args {
		log "lappend called with args $args";

		set name    [lindex $args 0];
		set lambda  {x {safe invokehidden lappend {*}$x}};

		if {[set ret [stack_check $name $lambda $args]] ne {}} {
			return $ret;
		} {
			set name [var_name $name];
			return [var_changed $name $lambda $args];
		}
	}

	proc _set args {
		log "Set called with args: $args";

		set name    [lindex $args 0];
		set lambda  {x {safe invokehidden set {*}$x}};

		if {[set ret [stack_check $name $lambda $args]] ne {}} {
			return $ret;
		} {
			set name [var_name $name];
			return [var_changed $name $lambda $args];
		}
	}
	
	# For unset, we can't use the generic stack_check and
	# var_changed mechanism we normally do, because unset returns
	# an empty string as a successful result, so we check manually
	proc _unset args {
		log "Secret unset invoked with $args";

		foreach var $args {
			log "Unsetting $var";

			set lambda  {x {safe invokehidden unset {*}$x}};

			set level [safe invokehidden info level];
			if {$level != 0 && ![regexp {::} $var]} {
				# We should just pass this through as it is a lexical
				# variable.
				apply $lambda {*}$var;
			} {
				set name [var_name $var];
				if {[safe invokehidden array exists $name]} {
					arr_changed $name $lambda $name;
				} {
					var_changed $name $lambda $name;
				}
			}
		}
	}

	proc _info args {
		log_debug{"Info called with $args"};
		if {[lindex $args 0] ne "hostname"} {
			set ret [safe invokehidden info {*}$args];
			return $ret;
		}
	}
}
