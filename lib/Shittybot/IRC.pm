package Shittybot::IRC;

use Modern::Perl        '2012';
use Shittybot::Log      ':log';
use AnyEvent::IRC::Util qw/prefix_nick prefix_user prefix_host/;
use Data::Dump          'ddx';
use Moose;

has 'client'    => (
	is          => 'ro',
	isa         => 'Shittybot::Client',
	required    => 1,
);

# Called when we or anyone else joins a channel
# TODO: Implement something useful
sub join {
	my $self    = shift;
	
	my $nick    = shift;
	my $channel = shift;
	my $isself  = shift;

}

# Called when nicks are added to a channel
# TODO: log the changes to a nick tracker
sub channel_add {
	my $self    = shift;

	my $msg     = shift;
	my $channel = shift;
	my @nicks   = @_;
}

# Called on a change of mode to a channel, this doesn't
# seem to actually give you any modes
sub channel_nickmode_update {
	my $self    = shift;

	my $channel = shift;
	my $changed = shift;

	log_debug{my $network = $self->client->network; "Mode for $changed changed on $channel ($network)"}; 
}

# TODO: Add to channel status tracker of some sort
sub channel_topic {
	my $self    = shift;

	my $channel = shift;
	my $topic   = shift;
	my $changer = shift;

	log_debug{my $network = $self->client->network; "Channel $channel ($network) topic changed to '$topic'"};
}

# Called when fully connected to a server, join our channels,
# identify ourselves to nick services and oper if needed
# TODO: identify and oper
sub registered {
	my $self    = shift;
	my $client  = $self->client;

	# Join our channels
	my $channels    = $client->network_config->{channels};
	for my $channel (@$channels) {
		log_warn{"Joining $channel on network '" . $client->network . "'"};
		$client->c->send_srv('JOIN', $channel);
	}
}

# Probably the most important function, public message handling
# TODO: everything
sub publicmsg {
	my $self    = shift;
	my $trigger = $self->client->network_config->{trigger};

	my $channel = shift;
	my $data    = shift;

	my $message = $data->{params}->[1];
	my $sender  = prefix_nick($data->{prefix});

	log_debug{my $network = $self->client->network; "$channel($network)> <$sender> $message"};

	if ($message    =~ m/$trigger/) {
		log_warn{my $network = $self->client->network; "$channel($network) runs $message"};
	}
}

# Called on error, we just blog it for now
# TODO: something useful
sub error {
	my $self    = shift;

	my $code    = shift;
	my $message = shift;
	my $ircmsg  = shift;

	log_error{"Holy crap error $code: $message (" . ddx($ircmsg) . ")"};
}

__PACKAGE__->meta->make_immutable;
