package Statweb;
use Mojo::Base 'Mojolicious';
use DBI;
use EV;
use AnyEvent;

my $db = '/tmp/statweb_state.sqlite';
my $dbh = DBI->connect("dbi:SQLite:dbname=$db","","",{RaiseError => 1});


#my $w = AnyEvent->timer (
#	after => 0.5, interval => 1, cb => sub {
#		warn "timeout\n";
#	};
#);
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
	my $s    = shift;
	my $sth = $dbh->prepare('SELECT * FROM status');
	$sth->execute;
	my $datatable = { aaData => [] };
	while ( $r = $sth->fetchrow_hashref() ) {
		my @t = [ $r->{'ts'}, $r->{'host'}, $r->{'service'}, $r->{'state'}, $r->{'msg'} ];
		push ( @{ $datatable->{'aaData'} }, @t);
	}

	$s->respond_to(
		json => {json => $datatable},
		xml  => {json => $datatable},
		txt  => {json => $datatable},
		html => {json => $datatable},
	);
	&db_cleanup;
	return "asdasd\n";
  });
  $r->get('/test')->to('example#welcome');
  $r->websocket('/ws' => sub {
      my $s = shift;
	  $s->on(message => sub {
					my ($self, $msg) = @_;
					$s->send("echo: $msg");
	  });
#	  $s->res->headers->content_type('text/event-stream');
#	  my $a = 0;
#	  while($a < 5) {
#		  sleep 1;
#		  ++$a;
#		  $s->write("event:msg\ndata: test\n\n");
#	  }
  });

}
sub db_cleanup {
	# cast have to be here else sqlite thinks its text and fails at compare
	my $sth = $dbh->prepare("UPDATE status SET state = -1 WHERE ( ts + ttl ) < CAST( ? AS INT)");
	$sth->execute(scalar time);
}
1;
#			$self->content_for(head => '<meta name="author" content="sri" />');
#			$self->render(template => 'hello', message => 'world')
