#!/usr/bin/perl

# NOTE: This may segfault unless run with PERL_DL_NONLAZY=1

use Modern::Perl    '2012';
use lib 'lib';

use Shittybot::Client;
use Config::JFDI;
use AnyEvent;

## anyevent main CV
my $cond = AnyEvent->condvar;

# load shittybot.yml/conf/ini/etc
my $config_raw = Config::JFDI->new(name => 'shittybot');
my $config = $config_raw->get;

my $networks = $config->{networks}
    or die "Unable to find network configuration";

# TODO
# Spawn modules to handle each state
my $states  = {};

# spawn client for each network
my $clients = {};

while (my ($net, $net_conf) = each %$networks) {
	$clients->{$net} = Shittybot::Client->new(
		network         => $net,
		clients         => $clients,
		states          => $states,
		config          => $config,
		network_config  => $net_conf,
	);
};

$cond->wait;
