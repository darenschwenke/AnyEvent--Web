#!/usr/bin/perl

use FindBin;

$server = {
	bind_ip 	=> '0.0.0.0', # interface to bind to
	bind_port 	=> 80, 	# port to bind to.
	server_id 	=> 1, # increment to keep pubsub/rpc id's unique for using multiple servers.
 	#tls      	=> "accept",
 	#tls_ctx  	=> { cert_file => "keycert.pem" },
	#rbuf_max 	=> 16 * 1024, 	# max allowed size of read buffer in bytes
	#wbuf_max 	=> 16 * 1024, 	# max allowed size of write buffer in bytes
	keepalive 	=> 1,			# if true, enable SO_KEEPALIVE on socket
	no_delay 	=> 0, 			# if true, write data as you provide it
	timeout 	=> 5, 			# idle connection timeout in seconds
};
$fileserver = {
	web_root 		=> "$FindBin::Bin/../webroot",
	cache_enable 	=> 1,
	cache_expire 	=> 30,
};
$websocket = {
	#rbuf_max 	=> 16 * 1024, 	# max allowed size of read buffer in bytes
	#wbuf_max 	=> 16 * 1024, 	# max allowed size of write buffer in bytes
	keepalive 	=> 1,			# if true, enable SO_KEEPALIVE on socket
	no_delay 	=> 0, 			# if true, write data as you provide it
	timeout 	=> 0, 			# idle connection timeout in seconds
	redis => $cfg::redis
};
$jqws_json = {
	%{$websocket},
	encoding => 'json'
};
$jqws_msgpack = {
	%{$websocket},
	encoding => 'msgpack'
};
$wamp = {
	%{$websocket},
	features => {
		roles		=> {
			broker 	=> {},
			dealer	=> {},
		},
	}
};
$wamp_json = {
	%{$wamp},
	encoding 	=> 'json',
};
$wamp_msgpack = {
	%{$wamp},
	encoding 	=> 'msgpack',
};

1;
