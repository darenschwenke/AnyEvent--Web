#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib/";
use AnyEvent::Web::Util qw(load_config);
use AnyEvent::Web;
use EV;

use Data::Dumper;
$Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 2;
$Data::Dumper::Sortkeys = 1;
use AnyEvent::Debug;
AnyEvent::Debug::wrap 2;


my $conf_dir = "$FindBin::Bin/../conf";
load_config("$conf_dir/redis.pl");
load_config("$conf_dir/config.pl");
load_config("$conf_dir/routes.pl");

my $server;
my $cv = AnyEvent->condvar;

$server = AnyEvent::Web->new($cfg::server,$cfg::routes);
$server->serve;

$cv->wait;
