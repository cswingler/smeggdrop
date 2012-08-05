encoding system utf-8
set ROOT_PATH [file dirname [info script]]

variable log;

proc log args {
	variable log;
	set log $args;
	readlog;
}
log "TCL Started";


# Set up revision control
source "$ROOT_PATH/rcs.tcl"
# Create safe interpreter
source "$ROOT_PATH/safe.tcl"
