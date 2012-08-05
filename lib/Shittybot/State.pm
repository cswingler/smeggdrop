package Shittybot::State;

use Modern::Perl    '2012';

use Shittybot::Log  ':log';
use Moose;
use AnyEvent;
use Tcl;
use Try::Tiny;

use Data::Dump      'ddx';

has 'name' => (
	is          => 'ro',
	isa         => 'Str',
	required    => 1,
);

has 'interpreter' => (
	is      => 'ro',
	isa     => 'Tcl',
	writer  => '_set_interpreter',
	builder => '_build_tcl',
);

sub BUILD {
	my $self    = shift;

	log_debug{"Created State object"};
	# TODO:
	# load state and fork workers
	$self->interpreter->EvalFile('tcllib/init.tcl');
}

sub _build_tcl {
	my $self    = shift;

	# TODO:
	# start the damn interpreter
	my $interp  = Tcl->new();
	log_debug{"Starting interpreter"};

	$interp->export_to_tcl(
		namespace   => '',
		subs        => {
			readlog => sub { $self->_tcl_log(@_) },
		},
	);

	return $interp;
}

sub _tcl_log {
	my $self    = shift;
	my $log     = $self->interpreter->GetVar('log', Tcl::GLOBAL_ONLY);

	for my $line (@$log) {
		log_debug{"Tcl: $line"};
	}
}

sub run {
	my $self    = shift;

	my $command = shift;

	log_debug{"Running command $command on state " . $self->name};

	$self->interpreter->SetVar('safe::command', $command);
	my @result;
	try {
		@result  = $self->interpreter->Eval('safe::run');
	} catch {
		$result[0]  = "Error: $_";
	};

	if (@result) {
		my $text    = join "\n", @result;
		log_debug{"Result from exec:\n########################\n@result\n#######################\n$text\n######################"};
		return $text;
	}
}


__PACKAGE__->meta->make_immutable;
