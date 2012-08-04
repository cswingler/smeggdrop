encoding system utf-8
set ROOT_PATH [file dirname [info script]]

variable log;

proc log args {
	variable log;
	set log $args;
	readlog;
}
log "TCL Started";

# Create safe interpreter
source "$ROOT_PATH/safe.tcl"
