package Statweb;
use Dancer ':syntax';

our $VERSION = '0.1';

# save pid
open(PID, '>', config->{'pidfile'});
print PID $$;
close(PID);

get '/' => sub {
    template 'index';
};
get '/:type/:action' => sub {
    template 'index';
};

true;
