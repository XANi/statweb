package Statweb;
use Mojo::Base 'Mojolicious';
use DBI;


my $db = '/tmp/statweb_state.sqlite';
my $dbh = DBI->connect("dbi:SQLite:dbname=$db","","",{RaiseError => 1});

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
		my @t = [ $r->{'ts'}, $r->{'host'}, $r->{'service'}, $r->{'state'}, $r->{'msg'} ];
		push ( @{ $datatable->{'aaData'} }, @t);
	}
	$self->respond_to(
		json => {json => $datatable},
		xml  => {json => $datatable},
		txt  => {json => $datatable},
		html => {json => $datatable},
	);
	return "asdasd\n";
  });
  $r->get('/test')->to('example#welcome');

}

1;
#			$self->content_for(head => '<meta name="author" content="sri" />');
#			$self->render(template => 'hello', message => 'world')
