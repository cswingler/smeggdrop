namespace eval safe {

	variable command;
	variable caller;
	variable auth;
	variable network;
	
	proc _build_interp {} {
		interp create -safe safe
	}

	proc run args {
		variable command;
		set result [safe eval $command];
		return $result;
	}

	_build_interp;
}
