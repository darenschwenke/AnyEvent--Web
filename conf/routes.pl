#!/usr/bin/perl

use FindBin;
use lib "$FindBin::Bin/../lib/";
use AnyEvent::Web::File;
use AnyEvent::Web::Socket::WAMP; 
use AnyEvent::Web::Socket::WebGL; 
use AnyEvent::Web::Socket::WebRTC; 
use AnyEvent::Web::Socket::jQApp; 

my $fileserver = AnyEvent::Web::File->new($cfg::fileserver);
 
$routes = [
	#{
	#	name => 'hello world',
	#	match_path => '/hello_world.html',
	#	handler => sub {
	#		my ($handle) = shift;
	#		$handle->push_write(
	#	  		"HTTP/1.1 200 OK\nConnection:Keep-Alive\nContent-Type: text/plain\nContent-Length: 11\n\nHello World"
	#	  	);
	#	  	#$handle->push_shutdown();
	#	}
	#},
	{
		name => 'rewrite ws_host',
		match_any => { 
			PATH => ['/js/jquery.onload.js','/webrtc.html','/webgl.html']
		},
		handler => sub {
			my ($handle) = shift;
			$handle->{request}->{rewrite} = sub {
				$r = shift;
				$r->{content_string} =~ s/__WS_HOST__/$r->{HTTP_HOST}/g;
			};
			$fileserver->serve($handle);
		}
	},
	{
		name => 'serve files',
		match_none => {
			HTTP_UPGRADE => qr/websocket/i,
			HTTP_CONNECTION => qr/Upgrade/i,
			PATH => ['/js/jquery.onload.js','/webrtc.html','/webgl.html']
		},	
		handler => sub {
			$fileserver->serve(@_);
		}
	},
	{
		name => 'serve /webgl websocket',
		match_all => {
			PATH => '/webgl',
			HTTP_UPGRADE => qr/websocket/i,
			HTTP_CONNECTION => qr/Upgrade/i,
		},
		handler => sub {
			AnyEvent::Web::Socket::WebGL->new(shift,$cfg::jqws_json);
		}
	},
	{
		name => 'serve /jqws websocket',
		match_all => {
			PATH => '/jqws_json',
			HTTP_UPGRADE => qr/websocket/i,
			HTTP_CONNECTION => qr/Upgrade/i,
		},
		handler => sub {
			AnyEvent::Web::Socket::jQApp->new(shift,$cfg::jqws_json);
		}
	},
	{
		name => 'serve /jqws websocket',
		match_all => {
			PATH => '/jqws_msgpack',
			HTTP_UPGRADE => qr/websocket/i,
			HTTP_CONNECTION => qr/Upgrade/i,
		},
		handler => sub {
			AnyEvent::Web::Socket::jQApp->new(shift,$cfg::jqws_msgpack);
		}
	},
	{
		name => 'serve /webrtc websocket',
		match_all => {
			PATH => '/webrtc',
			HTTP_UPGRADE => qr/websocket/i,
			HTTP_CONNECTION => qr/Upgrade/i,
		},
		handler => sub {
			AnyEvent::Web::Socket::WebRTC->new(shift,$cfg::websocket);
		}
	},
	{
		name => 'serve /wamp json websocket',
		match_all => {
			PATH => '/wamp',
			SEC_WEBSOCKET_PROTOCOL => qr/wamp\.2\.json|wamp$/i,
			HTTP_UPGRADE => qr/websocket/i,
			HTTP_CONNECTION => qr/Upgrade/i,
		},
		handler => sub {
			AnyEvent::Web::Socket::WAMP->new(shift,$cfg::wamp_json);
		}
	},
	{
		name => 'serve /wamp msgpack websocket',
		match_all => {
			PATH => '/wamp',
			SEC_WEBSOCKET_PROTOCOL => qr/wamp\.2\.msgpack/i,
			HTTP_UPGRADE => qr/websocket/i,
			HTTP_CONNECTION => qr/Upgrade/i,
		},
		handler => sub {
			AnyEvent::Web::Socket::WAMP->new(shift,$cfg::wamp_msgpack);
		}
	}
];

1;
