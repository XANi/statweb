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


my $tmp = read_file('/etc/statweb/agent.yaml') or croak("Can't load config: $!");
my $cfg = Load($tmp) or croak("Can't parse config: $!");



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

$log->debug("Dumping config:\n" . Dump($cfg));




my $ctxt = ZeroMQ::Context->new();
my $req = $ctxt->socket(ZMQ_PUB);
$log->info("Binding to ZMQ addr " . $cfg->{'sender'}{'default'}{'config'}{'address'});
$req->bind($cfg->{'sender'}{'default'}{'config'}{'address'});

$log->info("Starting check loop");
while(1) {
		&send({test => 'data'});
	sleep 1;
}

sub send() {
	my $data = shift;
	my $tag = $cfg->{'sender'}{'default'}{'tag'};
	$log->debug("sending with tag $tag");
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
