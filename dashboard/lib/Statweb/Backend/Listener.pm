package Statweb::Backend::Listener;
use common::sense;
use Carp qw(cluck croak carp);
use Data::Dumper;
use JSON;
use ZeroMQ qw/:all/;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration   use DPP::VCS::Git ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(

                                 ) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

               );

our $VERSION = '0.01';

#use vars qw( $GIT_DIR );


sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    bless($self, $class);
    my %config = @_;
    $self->{'config'} = \%config;
    return $self;
};

sub listen {
    my $s = shift;
    my $sub = shift;

    my $ctxt = ZeroMQ::Context->new();
    my $req = $ctxt->socket(ZMQ_SUB);
    if ( defined( $s->{'config'}{'address'} )) {
        print "Connecting to " . $s->{'config'}{'address'} . "\n";
        $req->connect( $s->{'config'}{'address'} );# or die("ZMQ error: $!");
    } else {
        croak("Listen address not defined");
    }
    if( defined( $s->{'config'}{'tag'} ) ) {
        $req->setsockopt(ZMQ_SUBSCRIBE, $s->{'config'}{'tag'});
    } else {
        $req->setsockopt(ZMQ_SUBSCRIBE, '');
    }
    while(1)  {
        my ($tag, $json) = split(/\|/, $req->recv->data,2);
        my $data;
        eval {
            $data = from_json($json);
        };
        if (defined($data->{'type'})) {
            &$sub($data);
        }
    }
};
1;


