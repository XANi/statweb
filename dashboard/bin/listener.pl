#!/usr/bin/perl
use common::sense;

use Statweb::Backend::Listener;
use YAML;
use Log::Dispatch;
use Log::Dispatch::Screen;
use File::Slurp;
use DBI;
use POSIX;
use YAML;
my $db = '/tmp/statweb_state.sqlite';
$0 = 'Statweb: listener';
my $create_db=0;
if ( ! -e $db) {
	$create_db=1;
}


my $tmp = read_file('/etc/statweb/listener.yaml') or croak("Can't load config: $!");
my $cfg = Load($tmp) or croak("Can't parse config: $!");

my $dbh = DBI->connect("dbi:SQLite:dbname=" . $cfg->{'db'},"","",{RaiseError => 1});

my $zmq=Statweb::Backend::Listener->new(
	address => $cfg->{'listener'}{'default'}{'address'}
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
my $sql = &prepare_sql($dbh);
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
    msg     TEXT,
    last_state   NUMERIC,
    last_state_change NUMERIC
);');

	$sth = $dbh->do('
CREATE TRIGGER update_state AFTER UPDATE ON status BEGIN
  UPDATE status SET
    last_state_change = NEW.ts,
    last_state = OLD.state
  WHERE
    status.host = NEW.host
    AND status.service = NEW.service
    AND OLD.state != NEW.state;
END;');
	$sth = $dbh->do('
CREATE TRIGGER insert_update_state AFTER INSERT ON status BEGIN
  UPDATE status SET
    last_state_change = NEW.ts,
    last_state = NEW.state
  WHERE
    status.host = NEW.host
    AND status.service = NEW.service;
END;') or die;
	$sth = $dbh->do('
CREATE TABLE status_log (
    ts           NUMERIC,
    host         TEXT,
    service      TEXT,
    ttl          NUMERIC,
    old_state    NUMERIC,
    new_state    NUMERIC,
    old_duration NUMERIC,
    msg TEXT
);') or die;
	$sth = $dbh->do('
CREATE TRIGGER archivize AFTER UPDATE ON status
  FOR EACH ROW WHEN OLD.state != NEW.state
  BEGIN
  INSERT INTO status_log (ts, host, service, ttl, old_state, new_state, old_duration, msg)
  VALUES(
    NEW.ts,
    NEW.host,
    NEW.service,
    OLD.ttl,
    OLD.state,
    NEW.state,
    NEW.ts - OLD.last_state_change,
    OLD.msg
  );
END;') or die;
}

sub insert_or_update_state {
	my $data = shift;
	$sql->{'get_status'}->execute (
		$data->{'host'},
		$data->{'service'},
	);
	my $r = $sql->{'get_status'}->fetchrow_hashref();
	$log->debug("Current\n" . Dump($r));
	if( defined ($r) ) {
		if( $r->{'state'} != $data->{'state'} ) {
			$log->debug("State changed from \n" . Dump($r));
		}
		$log->debug("Updating with:\n" . Dump($data) );
		$sql->{'update_status'}->execute(
			$data->{'state'},
			$data->{'msg'},
			scalar time,
			$data->{'ttl'},
			$data->{'host'},
			$data->{'service'},
		);
		if(!$dbh->{'AutoCommit'}) {
			$dbh->commit;
		}
	}
	else {
		$log->debug("Inserting:\n" . Dump($data) );
		$sql->{'insert_status'}->execute(
			scalar time,
			$data->{'host'},
			$data->{'service'},
			$data->{'state'},
			$data->{'msg'},
			$data->{'ttl'},
		);
#		$sql->{'update_prev_state'}->execute(
#			$data->{'host'},
#			$data->{'service'},
#		);
	}
}

sub prepare_sql {
	my $dbh = shift;
	my $sql;
	$sql->{'get_status'} = $dbh->prepare('SELECT * FROM status WHERE host = ? AND service = ? ORDER BY ts DESC LIMIT 1');
	$sql->{'update_status'} = $dbh->prepare('UPDATE status SET state = ?, msg = ?, ts = ?, ttl = ? WHERE host = ? AND service = ? ORDER BY ts DESC LIMIT 1');
	$sql->{'update_prev_state'} = $dbh->prepare('UPDATE status SET last_state = state, last_state_change = ts WHERE host = ? AND service = ? ORDER BY ts DESC LIMIT 1');
	$sql->{'insert_status'} = $dbh->prepare('INSERT INTO status (ts, host, service, state, msg, ttl) VALUES (?, ?, ?, ?, ?, ?)');
	return $sql;
}
sub keepalive {
	my $data = shift;
	$data->{'state'} = 0;
	$data->{'msg'} = 'Keepalive based on '. $data->{'service'};
	$data->{'service'} = 'keepalive';
	&insert_or_update_state($data);
}

