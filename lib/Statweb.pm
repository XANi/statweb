package Statweb;
use Dancer ':syntax';
use Statweb::RRD;
use Data::Dumper;
our $VERSION = '0.1';

# save pid
open(PID, '>', config->{'pidfile'});
print PID $$;
close(PID);

# load RRD list
my $rrddb = Statweb::RRD->new(config->{'rrd_dir'});


get '/' => sub {
    template 'index';
};

get '/rrd/list' => sub {
    if ( $ENV{'HTTP_ACCEPT'} =~ /text\/html/ ) { # if browser wants html give html
	template 'data', {content => Dumper $rrddb->get_index()};
    } else { # rely on Mutable to return either json or xml
	return $rrddb->get_index();
    }
};
post '/graph/dump' => sub {
#    if (!defined(params->{'template'} || !defined(params->{'select'}
#    $rrd->generate_graph_config($graph_template, $graph_params;
};

get '/:type/:action' => sub {
    template 'index';
};
true;
