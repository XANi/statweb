#!/usr/bin/perl
use common::sense;
use EV;
use AnyEvent;
use YAML::XS;
use JSON;
use ZeroMQ qw/:all/;
use File::Slurp;
use POSIX;
use Log::Dispatch;
use Log::Dispatch::Screen;
my $hosts_count = 30;
my $checks_count = 10;
my $interval = 10;
my $tmp = read_file('/etc/statweb/agent.yaml') or croak("Can't load config: $!");
my $cfg = Load($tmp) or croak("Can't parse config: $!");
#   # Send all logs to Log::Dispatch

my $log = Log::Dispatch->new();
$log->add(
    Log::Dispatch::Screen->new(
        name      => 'screen',
        min_level => 'debug',
        callbacks => (\&_log_helper_timestamp),
    )
);

my $ctxt = ZeroMQ::Context->new();
my $req = $ctxt->socket(ZMQ_PUB);
$req->bind($cfg->{'sender'}{'default'}{'config'}{'address'});
my $finish = AnyEvent->condvar;
my $events = {};
my $checks = {};
for( my $hostid=0; $hostid<$hosts_count; ++$hostid) {
    for(my $checkid=0; $checkid<$checks_count; ++$checkid ) {
#       $checks->{$hostid}{$checkid}{'warn'} = 3;
#       $checks->{$hostid}{$checkid}{'crit'} = 1;
        $checks->{'testhost' . $hostid}{'dummy' . $checkid}{'nothing'} = 1;
    }
}
while (my ($host, $services) = each(%$checks)) {
        while (my ($service,$cfg) = each(%$services) ) {
            $log->info("Adding host $host check $service");
            $events->{"$host - $service"} = AnyEvent->timer(
                after => rand(60),
                interval => $interval,
                cb => sub {
                    &send({
                        type    => 'state',
                        host    =>  $host,
                        service =>  $service,
                        msg     => 'dummy state',
                        state   => 0,
                        ttl     => 60,
                    });
                },);
        }
}
$finish->recv;

sub _log_helper_timestamp() {
    my %a = @_;
    my $out;
    my $multiline_mark = '';
    foreach( split(/\n/,$a{'message'}) ) {
        $out .= strftime('%Y-%m-%dT%H:%M:%S%z',localtime(time)) . ' ' . $a{'level'} . ': ' . $multiline_mark . $_ . "\n";
        $multiline_mark = '.  '
    }
    return $out
}
sub send() {
    my $data = shift;
    my $tag = 'dummy';
    $log->debug("sending with tag $tag");
    $log->debug(Dump $data);
    $req->send($tag . '|' . to_json($data));
}
