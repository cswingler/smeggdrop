package Shittybot::Client;

use Modern::Perl    '2012';

use Shittybot::Log  ':log';
use Shittybot::IRC;
use Data::Dump      qw/pp/;

use Moose;

#use AnyEvent::IRC::Connection;
use AnyEvent::IRC::Client;
#use AnyEvent::Socket;

sub BUILD {
	my $self    = shift;
	my $c       = $self->network_config;

	log_debug {"Starting IRC Client for '" . $self->network . "'"};

	# Create and set the client attribute
	# TODO: create abstracted send methods so the actual client object
	# is irrelevant
	my $client  = AnyEvent::IRC::Client->new();
	$self->c($client);
	
	# Register callbacks
	my $irc     = Shittybot::IRC->new(client    => $self);
	for my $event (qw/registered channel_add channel_remove channel_change
		channel_nickmode_update channel_topic join part kick nick_change
		away_status_change ctcp_ping ctcp_version quit publicmsg error/) {
			$client->reg_cb($event  => sub {shift; $irc->$event(@_) });
	}
	
	# Connect to server
	$client->connect($c->{address}, $c->{port}, {
		nick        => $c->{nickname} || 'Shittybot',
		user        => $c->{username} || 'shit',
		real        => $c->{realname} || 'Write a conf, moron',
		password    => $c->{password} || undef,
		timeout     => $c->{timeout}  || 30,
	});
}

## hash of channel => \@logs
#has 'logs' => (
#    is => 'rw',
#    isa => 'HashRef',
#    lazy => 1,
#    default => sub { {} },
#);
#
has 'c' => (
	is          => 'rw',
	isa         => 'AnyEvent::IRC::Client',
);
has 'config' => (
    is          => 'ro',
    isa         => 'HashRef',
    required    => 1,
);
has 'network' => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);
has 'network_config' => (
    is          => 'ro',
    isa         => 'HashRef',
    required    => 1,
);
has 'clients' => (
	is          => 'ro',
	isa         => 'HashRef',
	required    => 1,
);
has 'states' => (
	is          => 'ro',
	isa         => 'HashRef',
	required    => 1,
);
#
#has 'tcl' => (
#    is => 'ro',
#    isa => 'Shittybot::TCL',
#    lazy_build => 1,
#    handles => [qw/ safe_eval /],
#);
#
#sub _build_tcl {
#    my ($self) = @_;
#
#    my $config = $self->config;
#    
#    my $state_dir = $config->{state_directory};
#    my $traits = $config->{traits} || [];
#
#    my @traits = map { "Shittybot::TCL::Trait::$_" } @$traits;
#
#    my $tcl = Shittybot::TCL->new_with_traits(
#        state_path => $state_dir,
#        irc => $self,
#        traits => \@traits,
#    );
#
#    return $tcl;
#}
#
#sub init {
#    my ($self) = @_;
#
#    $self->init_irc;
#    $self->init_tcl;
#}
#
#sub init_tcl { shift->tcl }
#
#sub init_irc {
#    my ($self) = @_;
#
#    my $network_conf = $self->network_config;
#
#    # config
#    my $botnick    = $network_conf->{nickname};
#    my $bindip     = $network_conf->{bindip};
#    my $channels   = $network_conf->{channels};
#    my $botreal    = $network_conf->{realname};
#    my $botident   = $network_conf->{username};
#    my $botserver  = $network_conf->{address};
#    my $botport    = $network_conf->{port} || 6667;
#    my $operuser   = $network_conf->{operuser};
#    my $operpass   = $network_conf->{operpass};
#    my $nickserv   = $network_conf->{nickserv} || 'NickServ';
#    my $nickservpw = $network_conf->{nickpass};
#
#    my $ownername  = $network_conf->{ownername};
#    my $ownerpass  = $network_conf->{ownerpass};
#    my $sessionttl = $network_conf->{sessionttl};
#
#    # validate config
#    return unless $channels;
#    $channels = [$channels] unless ref $channels;
#
#    if ($ownername && $ownerpass && $sessionttl) {
#        $self->{auth} = new Shittybot::Auth(
#            'ownernick' => $network_conf->{ownername},
#            'ownerpass' => $network_conf->{ownerpass},
#            'sessionttl' => $network_conf->{sessionttl} || 0,
#        );
#    }
#
#    # save channel list for the interpreter
#    $self->{config_channel_list} = $channels;
#
#    # closures to be defined
#    my $init;
#    my $getNick;
#
#    ## getting it's nick back
#    $getNick = sub {
#        my $nick = shift;
#        # change your nick here
#        $self->send_srv('PRIVMSG' => $nickserv, "ghost $nick $nickservpw") if defined $nickservpw;
#        $self->send_srv('NICK', $nick);
#    };
#
#    ## callbacks
#    my $conn = sub {
#        my ($self, $err) = @_;
#        return unless $err;
#        say "Can't connect: $err";
#        #keep reconecting
#        $self->{reconnects}{$botserver} = AnyEvent->timer(
#            after => 1,
#            interval => 10,
#            cb => sub {
#                $init->();
#            },
#        );
#    };
#
#    $self->reg_cb(connect => $conn);
#    $self->reg_cb(
#        registered => sub {
#            my $self = shift;
#            say "Registered on IRC server";
#            delete $self->{reconnects}{$botserver};
#            $self->enable_ping(60);
#
#            # oper up
#            if ($operuser && $operpass) {
#                $self->send_srv(OPER => $operuser, $operpass);
#            }
#
#            # save timer
#            $self->{_nickTimer} = AnyEvent->timer(
#                after => 10,
#                interval => 30, # NICK RECOVERY INTERVAL
#                cb => sub {
#                    $getNick->($botnick) unless $self->is_my_nick($botnick);
#                },
#            );
#        },
#        ctcp => sub {
#            my ($self, $src, $target, $tag, $msg, $type) = @_;
#            say "$type $tag from $src to $target: $msg";
#        },
#        error => sub {
#            my ($self, $code, $msg, $ircmsg) = @_;
#            print STDERR "ERROR: $msg " . ddx($ircmsg) . "\n";
#        },
#        disconnect => sub {
#            my ($self, $reason) = @_;
#            delete $self->{_nickTimer};
#            delete $self->{rejoins};
#            say "disconnected: $reason. trying to reconnect...";
# 
#            #keep reconecting
#            $self->{reconnects}{$botserver} = AnyEvent->timer(
#                after => 10,
#                interval => 10,
#                cb => sub {
#                    $init->();
#                },
#            );
#        },
#        part => sub {
#            my ($self, $nick, $channel, $is_myself, $msg) = @_;
#            return unless $nick eq $self->nick;
#            say "SAPart from $channel, rejoining";
#            $self->send_srv('JOIN', $channel);
#        },
#        kick => sub {
#            my ($self, $nick, $channel, $msg, $nick2) = @_;
#            return unless $nick eq $self->nick;
#            say "Kicked from $channel; rejoining";
#            $self->send_srv('JOIN', $channel);
#
#            # keep trying to rejoin
#            $self->{rejoins}{$channel} = AnyEvent->timer(
#                after => 10,
#                interval => 60,
#                cb => sub {
#                    $self->send_srv('JOIN', $channel);
#                },
#            );
#        },
#        join => sub {
#            my ($self, $nick, $channel, $is_myself) = @_;
#            return unless $is_myself;
#
#            delete $self->{rejoins}{$channel};
#        },
#        nick_change => sub {
#            my ($self, $old_nick, $new_nick, $is_myself) = @_;
#            return unless $is_myself;
#            return if $new_nick eq $botnick;
#            $getNick->($botnick);
#        },
#    );
#
#    $self->ctcp_auto_reply ('VERSION', ['VERSION', 'Shittybot']);
#
#    # default crap
#    $self->reg_cb
#        (debug_recv =>
#             sub {
#                 my ($self, $ircmsg) = @_;
#                 return unless $ircmsg->{command};
#                 #say dump($ircmsg);
#                 if ($ircmsg->{command} eq '307') { # is a registred nick reply
#                     # do something
#                 }
#             });
#
#    my $trigger = $network_conf->{trigger};
#
#    my $parse_privmsg = sub {
#        my ($self, $msg) = @_;
#
#        my $chan = $msg->{params}->[0];
#        my $from = $msg->{prefix};
#
#        my $nick = prefix_nick($from);
#        my $mask = prefix_user($from)."@".prefix_host($from);
#
#        if ($self->{auth}) {
#            return if grep { $from =~ qr/$_/ } @{$self->{auth}->ignorelist};
#        }
#
#        my $txt = $msg->{params}->[-1];
#
#        if ($txt =~ qr/^admin\s/ && $self->{auth}) {
#            my $data = $txt;
#            $data =~ s/^admin\s//;
#            #$self->{auth}->from($from);
#            my @out = $self->{auth}->Command($from, $data);
#            $self->send_srv(@out);
#        }
#
#        if ($txt =~ qr/$trigger/) {
#            my $code = $txt;
#            $code =~ s/$trigger//;
#            say "Got trigger: [$trigger] $code";
#
#            # maybe we shouldn't execute this?
#            return if $self->looks_shady($from, $code);
#
#            # add log info to interperter call
#            my $loglines = $self->slurp_chat_lines($chan);
#	    my $cmd_ctx = Shittybot::Command::Context->new(
#		nick => $nick,
#		mask => $mask,
#		channel => $chan,
#		command => $code,
#		loglines => $loglines,
#	    );
#
#            $self->safe_eval($cmd_ctx);
#        } else {
#            $txt = Encode::decode( 'utf8', $txt );
#            $self->append_chat_line( $chan, $self->log_line($nick, $mask, $txt) );
#        }
#    };
#
#    $self->reg_cb(irc_privmsg => $parse_privmsg);
#
#    $init = sub {
#        $self->send_srv('PRIVMSG' => $nickserv, "identify $nickservpw") if defined $nickservpw;
#        $self->connect (
#            $botserver, $botport, { nick => $botnick, user => $botident, real => $botreal },
#            sub {
#                my ($fh) = @_;
#
#                if ($bindip) {
#                    my $bind = AnyEvent::Socket::pack_sockaddr(undef, parse_address($bindip));
#                    bind $fh, $bind;
#                }
#
#                return 30;
#            },
#        );
#
#        foreach my $chan (@$channels) {
#            next unless $chan;
#
#            say "Joining $chan on " . $self->network;
#
#            $self->send_srv('JOIN', $chan);
#
#            # ..You may have wanted to join #bla and the server
#            # redirects that and sends you that you joined #blubb. You
#            # may use clear_chan_queue to remove the queue after some
#            # timeout after joining, so that you don't end up with a
#            # memory leak.
#            $self->clear_chan_queue($chan);
#        }
#    };
#
#    $init->();
#}
#
#sub connect {
#    my ($self, $host, $port, $info, $pre) = @_;
#
#    if (defined $info) {
#	$self->{register_cb_guard} = $self->reg_cb (
#	    ext_before_connect => sub {
#		my ($self, $err) = @_;
#
#		unless ($err) {
#		    $self->register(
#			$info->{nick}, $info->{user}, $info->{real}, $info->{password}
#		    );
#		}
#
#		delete $self->{register_cb_guard};
#	    }
#	);
#    }
#
#    AnyEvent::IRC::Connection::connect($self, $host, $port, $pre);
#}
#
## log channel chat lines 
#sub append_chat_line {
#    my ($self, $channel, $line) = @_;
#    my $log = $self->logs->{$channel} || [];
#    push @$log, $line;
#    $self->logs->{$channel} = $log;
#    return $log;
#}
#
## retrieve channel log chat lines (as an array ref)
#sub get_chat_lines {
#    my ( $self, $channel ) = @_;
#    my $log = $self->logs->{$channel} || [];
#    return $log;
#}
#
## clear channel chat lines
## mutation
#sub clear_chat_lines {
#    my ($self, $channel) = @_;
#    $self->logs->{$channel} = [];
#}
## retrieve and clear channel chat lines (as an array ref)
## mutation
#sub slurp_chat_lines {
#    my ($self, $channel) = @_;
#    my $log = $self->get_chat_lines( $channel );
#    $self->clear_chat_lines( $channel );
#    return $log;
#}
## This is a data structure that is a chat long message
#sub log_line {
#    my ($self, $nick, $mask, $message) = @_;
#    return [ time(), $nick, $mask, $message ];
#}
#
#sub send_to_channel {
#    my ($self, $chan, $msg) = @_;
#
#    return unless $msg;
#    utf8::encode($msg);
#
#    $msg =~ s/\001ACTION /\0777ACTION /g;
#    $msg =~ s/[\000-\001]/ /g;
#    $msg =~ s/\0777ACTION /\001ACTION /g;
#
#    my @lines = split  "\n" => $msg;
#    my $limit = $self->network_config->{linelimit} || 20;
#
#    # split lines if they are too long
#    @lines = map { chunkby($_, 420) } @lines;
#
#    if (@lines > $limit) {
#	my $n = @lines;
#	@lines = @lines[0..($limit-1)];
#	push @lines, "error: output truncated to ".($limit - 1)." of $n lines total"
#    }
#
#    foreach my $line (@lines) {
#	$self->send_chan($chan, 'PRIVMSG', $chan, $line);
#    }
#}
#
#sub chunkby {
#    my ($a,$len) = @_;
#    my @out = ();
#    while (length($a) > $len) {
#	push @out,substr($a, 0, $len);
#	$a = substr($a,$len);
#    }
#    push @out, $a if (defined $a);
#    return @out;
#}

__PACKAGE__->meta->make_immutable;
