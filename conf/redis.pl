#!/usr/bin/perl

# ends up in $cfg::redis

$redis = {
	events => {
		host => 'localhost',
		port => '6379',
		lazy => 1,
		connection_timeout => 5,
		read_timeout => 5,
		reconnect => 1,
		encoding => 'utf8',
		on_connect => sub {},
		on_disconnect => sub {},
		on_connect_error => sub {
			my ($msg) = shift;
			warn("$msg\n");
		},
		on_error => sub {
			my ($msg,$code) = @_;
			warn("$msg: $code\n");
		}
	},
	state => {
		host => 'localhost',
		port => '6379',
		lazy => 1,
		connection_timeout => 5,
		read_timeout => 5,
		reconnect => 1,
		encoding => 'utf8',
		on_connect => sub { },
		on_disconnect => sub { },
		on_connect_error => sub {
			my ($msg) = shift;
			warn("$msg\n");
		},
		on_error => sub {
			my ($msg,$code) = @_;
			warn("$msg: $code\n");
		}
	}
};

1;