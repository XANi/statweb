#!/usr/bin/perl

use common::sense;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Carp qw{ croak carp confess cluck};
use YAML qw(Load LoadFile Dump);
use JSON;
use POSIX;
use Log::Dispatch;
use Log::Dispatch::Screen;
use Sys::Hostname;
use IPC::Open3;
use List::Util qw(min max);

use EV;
use AnyEvent;
use Statweb::Transport::STOMP;


my $config_files = [
    'cfg/config.yaml',
    '/etc/statweb/agent.yaml',
    'cfg/config.default.yaml',
];
my $cfg;
foreach my $f (@$config_files) {
    if (-r $f) {
        print "Using config from $f\n";
        $cfg = LoadFile($f);
        last;
    }
}

my $host = hostname;
$0 = 'Statweb: agent';
# set up logging

if ( defined($cfg->{'pid'}) ) {
    open(PID, '>', $cfg->{'pid'});
    print PID $$;
    close(PID);
}

#   # Send all logs to Log::Dispatch
my $log = Log::Dispatch->new();
$log->add(
    Log::Dispatch::Screen->new(
        name      => 'screen',
        min_level => 'debug',
        callbacks => (\&_log_helper_timestamp),
    )
);

# init default vars if not defined
my $defaults = {
    default_check_interval => 300,
    keepalive => 60,
    randomize => 0,
    random_start => 1,
};
while ( my ($k, $v) = each(%$defaults) ) {
    if ( !defined( $cfg->{$k} ) ) {
        $cfg->{$k} = $v;
    }
}

$log->debug("Dumping config:\n" . Dump($cfg));

my $stomp;
if (defined( $cfg->{'sender'}{'stomp'} )) {
    $stomp = Statweb::Transport::STOMP->new($cfg->{'sender'}{'stomp'});
};

$log->info("Starting check loop");
my $next_check_t=0;
my $next_keepalive=0;
my $event;
my $finish = AnyEvent->condvar;
while ( my ($check_name, $check) = each(%{ $cfg->{'checks'} } ) ) {
    if( !defined ( $check->{'interval'} ) ) {
        $check->{'interval'} = $cfg->{'default_check_interval'} ;
    }
    if( !defined ( $check->{'ttl'} ) ) {
        $check->{'ttl'} = $check->{'interval'} * 4.1;
    }
    my $check_interval = $check->{'interval'};

    if ($cfg->{'randomize'} > 0) {
        my $randomize_percent = $check->{'interval'} * ( $cfg->{'randomize'} / 100 );
        $check_interval +=  ( $randomize_percent / 2 ) - rand($randomize_percent);
        $check_interval = max(1, $check_interval);
    }
    if ( $check->{'type'} eq 'nagios' ) {
        my $params;
        if (ref( $check->{'params'} ) ne 'ARRAY' ) {
            my @t = split( /\s+/, $check->{'params'} );
                    $params = \@t;
        }
        else {
            $params = $check->{'params'};
        }

        $log->debug("Scheduling check $check_name with time $check_interval starting in " . $cfg->{'random_start'} .'s');
        $event->{$check_name} = AnyEvent->timer(
            after => rand($cfg->{'random_start'}),
            interval => $check_interval,
            cb => sub {
                my($code, $msg) = &check_nagios( $check->{'plugin'}, $params );
                if (defined($check->{'strip_perfdata'}) && $check->{'strip_perfdata'} ) {
                    ($msg) = split(/\|/,$msg,2);
                }
                &send({
                    type    => 'state',
                    host    => $host,
                    service => $check_name,
                    msg     => $msg,
                    state   => $code,
                    ttl     => $check->{'ttl'},
                });
            },
        );
    }
    elsif ( $check->{'type'} eq 'dummy' ) {
                $log->debug("Scheduling dummy check $check_name with time $check_interval starting in " . $cfg->{'random_start'} .'s');
        $event->{$check_name} = AnyEvent->timer(
            after => rand($cfg->{'random_start'}),
            interval => $check_interval,
            cb => sub {
                my ($code, $msg) = &check_dummy($check_name, $check);
                &send({
                    type    => 'state',
                    host    => $host,
                    service => $check_name,
                    msg     => $msg,
                    state   => $code,
                    ttl     => $check->{'ttl'},
                });
            },)
    }
}

# wait till something tells us to exit
$finish->recv;


sub send() {
    my $data = shift;
    my $tag = $cfg->{'sender'}{'default'}{'tag'};
    if (defined($stomp)) {
        $stomp->send($data);
    }
    $log->debug("sending with tag $tag");
    $log->debug(Dump $data);
}


sub _log_helper_timestamp() {
    my %a = @_;
    my $out;
    my $multiline_mark = '';
    foreach( split(/\n/,$a{'message'}) ) {
        $out .= strftime('%Y-%m-%dT%H:%M:%S%z',localtime(time)) . ' ' . $a{'level'} . ': ' . $multiline_mark . $_ . "\n";
        $multiline_mark = '.  '
    }
    return $out
}

sub check_nagios {
    my $plugin = shift;
    my $plugin_parameters = shift;
    my $plugin_dir = '/usr/lib/nagios/plugins';
    if ( ref($plugin_parameters) eq 'ARRAY' ) {
        open(CHECK, '-|', $plugin_dir . '/' . $plugin, @$plugin_parameters);
    } else {
        open(CHECK, '-|', $plugin_dir . '/' . $plugin, $plugin_parameters);
    }
    my $msg;
    while(<CHECK>) {
        $msg .= $_;
    }
    chomp($msg);
    close(CHECK);
    my $code = $? >> 8;
    return ($code, $msg);
}

sub check_dummy {
    my $plugin = shift;
    my $params = shift;
    my $state = 0;
    if ( !defined( $params->{'warn'} ) ) {
        $params->{'warn'} = 0;
    }
    if ( !defined( $params->{'crit'} ) ) {
        $params->{'warn'} = 0;
    }
    my $roll = rand(100);
    if($roll < ( $params->{'crit'} ) ) {
        $state = 2;
    } elsif ($roll < ( $params->{'crit'} + $params->{'warn'} ) ) {
        $state = 1;
    }
    return ($state, 'Dummy check with ' . $params->{'warn'} . '% warn, ' . $params->{'crit'} . '% crit'. '[ roll: ' . $roll . ' ]');
}
