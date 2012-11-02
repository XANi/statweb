package Statweb;
use Mojo::Base 'Mojolicious';
use File::Slurp;
use DBI;
use YAML;

my $tmp = read_file('/etc/statweb/listener.yaml') or croak("Can't load config: $!");
my $cfg = Load($tmp) or croak("Can't parse config: $!");
my $dbh = DBI->connect("dbi:SQLite:dbname=" . $cfg->{'db'},"","",{RaiseError => 1});

$0 = 'Statweb: dashboard';
# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer');

  # Router
  my $r = $self->routes;

  # Normal route to controller
  $r->get('/')->to('example#welcome');
  $r->get('/datatables' => sub {
	my $self    = shift;
	my $sth = $dbh->prepare('SELECT * FROM status');
	$sth->execute;
	my $datatable = { aaData => [] };
	while ( $r = $sth->fetchrow_hashref() ) {
		my @t = [ $r->{'ts'}, $r->{'host'}, $r->{'service'}, $r->{'state'}, $r->{'last_state_change'}, $r->{'msg'} ];
		push ( @{ $datatable->{'aaData'} }, @t);
	}

	$self->respond_to(
		json => {json => $datatable},
		xml  => {json => $datatable},
		txt  => {json => $datatable},
		html => {json => $datatable},
	);
	&db_cleanup;
	return "asdasd\n";
  });
  $r->get('/test')->to('example#welcome');

};
sub db_cleanup {
	# cast have to be here else sqlite thinks its text and fails at compare
	my $sth = $dbh->prepare("UPDATE status SET state = -1 WHERE ( ts + ttl ) < CAST( ? AS INT)");
	$sth->execute(scalar time);
	$sth = $dbh->prepare("UPDATE status SET state = -2 WHERE ( ts + 3600 ) < CAST( ? AS INT)");
	$sth->execute(scalar time);
	$sth = $dbh->prepare("DELETE FROM status WHERE ( ts + 86400 ) < CAST( ? AS INT )");
	$sth->execute(scalar time);
};
1;
#			$self->content_for(head => '<meta name="author" content="sri" />');
#			$self->render(template => 'hello', message => 'world')
