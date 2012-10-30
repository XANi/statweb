#!/usr/bin/perl
use common::sense;

use Statweb::Backend::Listener;
use YAML;
use Log::Dispatch;
use Log::Dispatch::Screen;
use DBI;
use POSIX;
my $db = '/tmp/statweb_state.sqlite';
my $create_db=0;
if ( ! -e $db) {
	$create_db=1;
}
my $dbh = DBI->connect("dbi:SQLite:dbname=$db","","",{RaiseError => 1});
my $zmq=Statweb::Backend::Listener->new(
	address => "epgm://$ARGV[0];239.3.2.1:5555",
);

my $default_ttl=600;

# TODO pack it into submodule
my $log = Log::Dispatch->new();
$log->add(
	Log::Dispatch::Screen->new(
		name      => 'screen',
		min_level => 'debug',
		callbacks => (\&_log_helper_timestamp),
	)
);

if ( $create_db ) {
	$log->warn("creating DB");
	&create_db;
}
my $var;
$zmq->listen(
	sub {
		++$var;
		my $data = shift;
		if ( defined ( $data->{'type'} ) && $data->{'type'} eq 'state' ) {
			if (! defined($data->{'ttl'}) ) {
				$data->{'ttl'} = $default_ttl;
			}
			&insert_or_update_state($data);
			&keepalive($data);
		}
	}
);



sub _log_helper_timestamp {
	my %a = @_;
	my $out;
	my $multiline_mark = '';
	foreach( split(/\n/,$a{'message'}) ) {
		$out .= strftime('%Y-%m-%dT%H:%M:%S%z',localtime(time)) . ' ' . $a{'level'} . ': ' . $multiline_mark . $_ . "\n";
		$multiline_mark = '.  '
	}
	return $out
}

sub create_db {
	my $sth = $dbh->do('
CREATE TABLE status (
    ts      NUMERIC,
    host    TEXT,
    service TEXT,
    state   NUMERIC,
    ttl     NUMERIC,
    msg     TEXT
)');
}

sub insert_or_update_state {
	my $data = shift;
	my $sth = $dbh->prepare('UPDATE status SET state = ?, msg = ?, ts = ?, ttl = ? WHERE host = ? AND service = ? ORDER BY ts DESC LIMIT 1');
	my $count = $sth->execute(
		$data->{'state'},
		$data->{'msg'},
		scalar time,
		$data->{'ttl'},
		$data->{'host'},
		$data->{'service'},
	);
	if ($count < 1) {
		$log->debug("Inserting:\n" . Dump($data) );
		my $sth = $dbh->prepare('INSERT INTO status (ts, host, service, state, msg, ttl) VALUES (?, ?, ?, ?, ?, ?)');
		$sth->execute(
			scalar time,
			$data->{'host'},
			$data->{'service'},
			$data->{'state'},
			$data->{'msg'},
			$data->{'ttl'},
		);
	}
	else {
		$log->debug("Updating $count rows with:\n" . Dump($data) );
	}
}

sub keepalive {
	my $data = shift;
	$data->{'state'} = 0;
	$data->{'msg'} = 'Keepalive based on '. $data->{'service'};
	$data->{'service'} = 'keepalive';
	&insert_or_update_state($data);
}

