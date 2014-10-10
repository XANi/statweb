package Statweb::Transport::STOMP;
use common::sense;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Moo;
use AnyEvent::STOMP::Client;
use Log::Any qw($log);
use JSON::XS;
use Crypt::Mac::HMAC qw(hmac_hex );

has host => (
    is => 'ro',
    default => sub { 'localhost' },
);

has port => (
    is => 'ro',
    default => sub { '61613' },
);

has user => (
    is => 'ro',
    default => sub { 'monitor' },
);

has pass => (
    is => 'ro',
    default => sub { 'monitor' },
);

has vhost => (
    is => 'ro',
    default => sub { '/' },
);

has exchange => (
    is => 'ro',
    default => sub {'statweb'},
);

has routing_key => (
    is => 'ro',
    default => sub {'status'},
);

has reconnect_interval => (
    is => 'ro',
    default => sub {5}
);

has hmac => (
    is => 'ro',
    default => sub {1},
);

# it is in miliseconds
has ttl => (
    is => 'ro',
    default => sub {600000}
);

has hmac_key => (
    is => 'rw',
    # this is just so we can actually test it
    default => sub {"bogus mac" . rand()},
);

has msg_handler => (
    is => 'ro',
    default => undef,
);

sub BUILD {
    my $self = shift;
    $self->{'client'} = AnyEvent::STOMP::Client->new(
        $self->host,
        $self->port,
        {
            'login' => $self->user,
            'passcode' => $self->pass,
            'virtual-host' => $self->vhost
        }
    );
    $self->{'watchdog'} = AnyEvent->timer(
        after => 60,
        interval => 600,
        cb => sub {
            if (!$self->{'client'}->is_connected) {
                $log->warn("watchdog: Not connected, reconnecting");
                $self->connect;

            }
        }
    );
    if( defined( $self->msg_handler) ) {
        $self->{'client'}->on_connected(
            sub {
                $log->info("Connected");
                $self->{'client'}->subscribe('/exchange/' . $self->exchange . '/' . $self->routing_key);
                $self->{'client'}->on_message($self->msg_handler);
            }
        );
    }
    else {
        $self->{'client'}->on_connected(
            sub {
                $log->info("Connected");
            }
        );
    }
    $self->{'client'}->on_disconnected(
        sub {
            $log->error("disconnected via DISCONNECT frame");
            $self->{'reconnect_timer'} = AnyEvent->timer(
                after => $self->reconnect_interval,
                cb => sub {
                    delete $self->{'reconnect_timer'};
                    $self->connect;
                },
            );
        }
    );
    $self->{'client'}->on_connect_error(
        sub {
            $log->error("connect error");
            $self->{'reconnect_timer'} = AnyEvent->timer(
                after => $self->reconnect_interval,
                cb => sub {
                    delete $self->{'reconnect_timer'};
                    $self->connect;
                },
            );
        }
    );
    $self->{'client'}->on_connection_lost(
        sub {
            $log->error("connection lost");
            $self->{'reconnect_timer'} = AnyEvent->timer(
                after => $self->reconnect_interval,
                cb => sub {
                    delete $self->{'reconnect_timer'};
                    $self->connect;
                },
            );
        }
    );
    $self->connect;
};

sub connect {
    my $self = shift;
    $log->info('Connecting to ' . $self->host . ':' . $self->port . ' vhost: ' . $self->vhost);
    $self->{'client'}->connect();

}




sub send {
    my $self = shift;
    my $msg;
    if (ref($_[0]) eq 'HASH') {
        $msg = shift;
    } else {
        $msg = { @_ }
    }
    my $encoded_msg = encode_json($msg);
    my $headers = {
        'content-type' => 'application/json',
        'expiration'   => $self->ttl,
    };
    $headers->{'hmac'} = hmac_hex('SHA256', $self->hmac_key, $encoded_msg);
    $self->{'client'}->send(
              '/exchange/' . $self->exchange . '/' . $self->routing_key,
              $headers,
              $encoded_msg,
          );
};


1;
