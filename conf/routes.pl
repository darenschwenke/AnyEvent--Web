#!/usr/bin/perl

use FindBin;
use lib "$FindBin::Bin/../lib/";
use AnyEvent::Web::File;
use AnyEvent::Web::Socket::WAMP; 
use AnyEvent::Web::Socket::WebRTC; 
use AnyEvent::Web::Socket::jQApp; 

my $fileserver = AnyEvent::Web::File->new($cfg::fileserver);
 
$routes = [
	{
		name => 'rewrite ws_host',
		match => { 
			PATH => ['/js/jquery.onload.js','/webrtc.html']
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
		name => 'serve /jqws websocket',
		match_all => {
			PATH => '/jqws',
			HTTP_UPGRADE => qr/websocket/i,
			HTTP_CONNECTION => qr/Upgrade/i,
		},
		handler => sub {
			return AnyEvent::Web::Socket::jQApp->new(shift,$cfg::websocket);
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
			return AnyEvent::Web::Socket::WebRTC->new(shift,$cfg::websocket);
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
			return AnyEvent::Web::Socket::WAMP->new(shift,$cfg::wamp_json);
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
			return AnyEvent::Web::Socket::WAMP->new(shift,$cfg::wamp_msgpack);
		}
	},
	{
		name => 'serve files',
		handler => sub {
			$fileserver->serve(@_);
		}
	}
];

1;
