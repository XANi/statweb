#!/usr/bin/perl
use common::sense;

use Statweb::Backend::Listener;
use YAML;


my $zmq=Statweb::Backend::Listener->new(
    address => 'epgm://eth0;239.3.2.1:5555',
);

$zmq->listen(
    sub {
        my $data = shift;
        print "Received message!\n";
        print Dump($data);
    }
);
