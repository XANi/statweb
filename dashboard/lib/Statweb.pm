package Statweb;
use Mojo::Base 'Mojolicious';
use File::Slurp;
use DBI;
use YAML;
use Data::Dumper;

my $tmp = read_file('/etc/statweb/dashboard.yaml') or croak("Can't load config: $!");
my $cfg = Load($tmp) or croak("Can't parse config: $!");
my $dbh = DBI->connect("dbi:SQLite:dbname=" . $cfg->{'db'},"","",{RaiseError => 1});

if ( defined($cfg->{'pid'}) ) {
    open(PID, '>', $cfg->{'pid'});
    print PID $$;
    close(PID);
}

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
    while ( my $row = $sth->fetchrow_hashref() ) {
        my @t = [ $row->{'ts'}, $row->{'host'}, $row->{'service'}, $row->{'state'}, $row->{'last_state_change'}, $row->{'msg'} ];
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
  $r->get('/host/*host' => sub {
              my $self = shift;
              my $datatable = {aaData => [] };
               my $sth = $dbh->prepare('SELECT * FROM status_log WHERE host = ?');
               $sth->execute($self->param('host'));
               while ( my $row = $sth->fetchrow_hashref() ) {
                  my @t = [ $row->{'ts'}, $row->{'host'}, $row->{'service'}, $row->{'old_state'}, $row->{'new_state'}, $row->{'duration'}, $row->{'msg'} ];
                  push ( @{ $datatable->{'aaData'} }, @t);
              }
              $self->stash(
                  host => $self->param('host'),
              );
              $self->respond_to(
                  json => {json => $datatable},
                  xml  => {json => $datatable},
                  txt  => {template => 'layouts/host'},
                  html => {template => 'layouts/host'},
              );

          },
      );
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
#           $self->content_for(head => '<meta name="author" content="sri" />');
#           $self->render(template => 'hello', message => 'world')
