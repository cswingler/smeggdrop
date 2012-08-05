namespace eval rcs {
	# Revision Control System for tcl

	variable check_vars;

	proc var_changed {name {old {}}} {
		if {[safe invokehidden info exists $name]} {
			set new [safe invokehidden set $name];
			if {$old ne {}} {
				log "Changed $name from $old to $new";
			} {
				log "Created $name variable: $new";
			}
		} {
			log "Variable $name deleted";
		}
	}

	proc array_created {name} {
		log "Array $name created";
	}

	proc array_deleted {name} {
		log "Array $name deleted";
	}
	
	proc _global args {
		variable check_vars;
		log "Global called with args: $args";

		set ret {};
		foreach var $args {
			if {![regexp {^::} $var]} {set var "::$var"}
			log "Adding $var to check vars";
			if {[safe invokehidden info exists $var]} {
				log "Adding $var to check_vars";
				set check_vars($var) [safe invokehidden set $var];
			}
			append ret [safe invokehidden global $var];
		}
		log "Check: [array get check_vars]";
		return $ret;
	}

	proc _set args {
		log "Set called with args: $args";

		set varname [lindex $args 0];
		set varval  {};
		set arrayexists 0;

		# Get the interpreters current stack frame and determine
		# if we have been called directly or indirectly.
		# If indirectly, we require that a namespace be
		# prepended before we store revisions to the variable
		set frame [safe invokehidden info frame [safe invokehidden info level]];
		if {[lindex 7] ne $args && ![regexp {::} $varname]} {
			# We should just pass this through as it is a lexical
			# variable. God knows how to handle 'global'ised ones
			# TODO: test global vars and learn some shit
			set ret [safe invokehidden set {*}$args];
			return $ret;
		}

		if {[safe invokehidden info exists $varname]} {
			# If the variable already exists, get the current value
			set varval [safe invokehidden set $varname];
		}

		if {[regexp {^(\w+)\(.*\)$} $varname match aname]} {
			# If it doesn't, but it might create an array, check
			# whether it already exists
			if {[safe invokehidden array exists $aname] == 1} {
				set arrayexists 1;
			}
		}

		set ret [safe invokehidden set {*}$args];
		# Test for implicit array creation
		if {[regexp {^(\w+)\(.*\)$} $varname match aname] && \
		  $arrayexists == 0 && [safe invokehidden array exists $aname]} {
			array_created $aname;
		}

		var_changed $varname $varval;
		return $ret;
	}

	proc _unset args {
		log "Secret unset invoked with $args";

		set ret {};
		foreach var $args {
			log "Unsetting $var";
			if {[safe invokehidden array exists $var]} {
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
