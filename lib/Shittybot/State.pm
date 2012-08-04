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
	builder => '_init_tcl',
);

sub BUILD {
	my $self    = shift;

	log_debug{"Created State object"};
	# TODO:
	# load state and fork workers
}

sub _init_tcl {
	my $self    = shift;

	# TODO:
	# start the damn interpreter
	my $interp  = Tcl->new();
	log_debug{"Starting interpreter"};
	$interp->EvalFile('tcllib/init.tcl');

	return $interp;
}

sub run {
	my $self    = shift;

	my $command = shift;

	log_debug{"Running command $command on state " . $self->name};

	$self->interpreter->SetVar('safe::command', $command);
	my $result;
	try {
		$result  = $self->interpreter->Eval('safe::run');
	} catch {
		$result  = "Error: $_";
	}

	log_debug{ddx($result)};
	return $result;
}


__PACKAGE__->meta->make_immutable;
