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
	address => 'epgm://br0;239.3.2.1:5555',
);

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
			my $sth = $dbh->prepare('UPDATE status SET state = ?, msg = ?, ts = ? WHERE host = ? AND service = ?');
			my $count = $sth->execute(
				$data->{'state'},
				$data->{'msg'},
				scalar time,
				$data->{'host'},
				$data->{'service'},
			);
			if ($count < 1) {
				$log->debug("Inserting:\n" . Dump($data) );
				my $sth = $dbh->prepare('INSERT INTO status (ts, host, service, state, msg) VALUES (?, ?, ?, ?, ?)');
				$sth->execute(
					scalar time,
					$data->{'host'},
					$data->{'service'},
					$data->{'state'},
					$data->{'msg'},
				);
			} else {
				$log->debug("Updating:\n" . Dump($data) );
			}
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
    msg     TEXT
)');
}
