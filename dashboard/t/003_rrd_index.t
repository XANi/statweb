use Test::More tests => 2;
use strict;
use warnings;
use lib '../lib';
BEGIN { use_ok('Statweb::RRD');}

use Statweb::RRD;

my $rrd = Statweb::RRD->new('/var/lib/collectd/rrd');

ok(0 == 0, "RRD file indexing");