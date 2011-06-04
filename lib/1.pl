#!/usr/bin/perl
use Statweb::RRD;

my $rrd = Statweb::RRD->new('/var/lib/collectd/rrd');
ok(0 eq 0, "RRD Indexing");
