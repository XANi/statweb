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
    $self->{'client'}->connect();
};

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

sub recv {
    my $self = shift;
    my $recv_handle = shift;
    $self->{'client'}->subscribe('/exchange/' . $self->exchange . '/' . $self->routing_key);
    $self->{'client'}->on_message($recv_handle);
}
1;
