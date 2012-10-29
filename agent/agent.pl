#!/usr/bin/perl

use common::sense;
use Carp qw{ croak carp confess cluck};

use ZeroMQ qw/:all/;
use File::Slurp;
use YAML;
use JSON;
use POSIX;
use Log::Dispatch;
use Log::Dispatch::Screen;
use Sys::Hostname;
use IPC::Open3;
use List::Util qw(min max);

my $tmp = read_file('/etc/statweb/agent.yaml') or croak("Can't load config: $!");
my $cfg = Load($tmp) or croak("Can't parse config: $!");

my $host = hostname;

# set up logging

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
};
while ( my ($k, $v) = each(%$defaults) ) {
	if ( !defined( $cfg->{$k} ) ) {
		$cfg->{$k} = $v;
	}
}


$log->debug("Dumping config:\n" . Dump($cfg));

my $ctxt = ZeroMQ::Context->new();
my $req = $ctxt->socket(ZMQ_PUB);
$log->info("Binding to ZMQ addr " . $cfg->{'sender'}{'default'}{'config'}{'address'});
$req->bind($cfg->{'sender'}{'default'}{'config'}{'address'});

$log->info("Starting check loop");
my $next_check_t=0;
my $next_keepalive=0;
while(1) {
	my $t = scalar time;
	if($next_check_t > $t) {
		my $sleep_time = max($next_check_t - $t, 1);
		$log->debug("Sleeping $sleep_time time before next check");
		sleep($sleep_time);
		next;
	}
	if ($next_keepalive <= $t ) {
		$log->debug('sending keepalive');
		&send({
			type    => 'state',
			host    => $host,
			service => 'keepalive',
			msg     => 'Alive',
			state   => '0',

		});
		$next_keepalive = $t + $cfg->{'keepalive'} + rand($cfg->{'randomize'});;
		$next_check_t = $next_keepalive;
	}
		while ( my ($check_name, $check) = each(%{ $cfg->{'checks'} } ) ) {
			if( !defined ( $check->{'interval'} ) ) {
				$check->{'interval'} = $cfg->{'default_check_interval'} ;
			}
			if( !defined ( $check->{'next_check'} ) ) {
				$check->{'next_check'} = $t;
			}

			if ( $check->{'next_check'} > $t ) {
				next;
			}
			else {
				$check->{'next_check'} = $t + $check->{'interval'} + rand($cfg->{'randomize'});;
				$next_check_t = min ( $check->{'next_check'}, $next_check_t );
			}

			if ( $check->{'type'} eq 'nagios' ) {
				my $params;
				$log->debug("Running check $check_name");
				if (ref( $check->{'params'} ) ne 'ARRAY' ) {
					my @t = split( /\s+/, $check->{'params'} );
					$params = \@t;
				}
				else {
					$params = $check->{'params'};
				}
				my($code, $msg) = &check_nagios( $check->{'plugin'}, $params );

				&send({
					type    => 'state',
					host    => $host,
					service => $check_name,
					msg     => $msg,
					state   => $code,
				});
			}
		}
}

sub send() {
	my $data = shift;
	my $tag = $cfg->{'sender'}{'default'}{'tag'};
	$log->debug("sending with tag $tag");
	$log->debug(Dump $data);
	$req->send($tag . '|' . to_json($data));

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
