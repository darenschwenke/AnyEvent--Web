
package AnyEvent::Web::Socket;
use AnyEvent qw(timer);
use JSON::XS;
use Data::Dumper;
use Data::MessagePack;
use Data::MessagePack::Stream;
use Protocol::WebSocket::Frame;
use AnyEvent::Web::Util qw(print_unicode);
use Protocol::WebSocket::Handshake::Server;
use constant SOCKET_DEBUG => 1;
use constant SOCKET_FRAME_DEBUG => 0;

sub new {
	my ($caller,$handle,$config) = @_;
	my $class = ref($caller) || $caller;
	my $self = {
		encoding			=> 'json',
		%{$config},
		_handle				=> $handle,
		_class				=> $class,	
		_authenticated		=> 0,
		_frame				=> Protocol::WebSocket::Frame->new(),
		_handshake			=> Protocol::WebSocket::Handshake::Server->new(),
	};
	bless $self, $class;
	print STDERR $class . ' handling socket via rule ' . $handle->{request}->{ROUTE} . "\n" if ROUTE_DEBUG;
	$self->encoding($self->{encoding});
  	if (!$self->{_handshake}->is_done) {
		print STDERR $self->{_handle}->{id} . ' ' . $class . " WebSocket handshake started.\n" if SOCKET_DEBUG;
		$self->{_handshake}->parse($self->{_handle}->{rbuf});
		$self->{_handle}->{rbuf} = undef;
		if ($self->{_handshake}->is_done) {
			print STDERR $self->{_handle}->{id} . ' ' . $class . " WebSocket handshake done.\n" if SOCKET_DEBUG;
			my $ws_frame = $self->{_handshake}->build_frame;
			$self->{_auth_timer} 	= AnyEvent->timer (
				after => $self->{auth_timeout}, 
				cb => sub {
					$self->{_handle}->push_shutdown() if ! $self->{_authenticated};
				}
			) if $self->{auth_timeout};
			$self->{_handle}->timeout($self->{idle_timeout});
			$self->{_handle}->push_write($self->{_handshake}->to_string);
			$handle->{rbuf} = undef;
			$self->{_handle}->on_eof(sub {
				my ($handle) = shift;
				$self->on_close();
			});
			$self->{_handle}->on_read(sub {
				my ($handle) = shift;
				print STDERR $self->{_handle}->{id} . ' ' . $self->{_class} . " on_read frame appending: " . print_unicode($handle->{rbuf}) . "\n" if SOCKET_FRAME_DEBUG;
				$ws_frame->append($handle->{rbuf});
				$handle->{rbuf} = undef;
				if ( $ws_frame->is_text ) {
					print STDERR $self->{_handle}->{id} . ' ' . $self->{_class} . " on_text triggered.\n" if SOCKET_FRAME_DEBUG;
					$self->on_text($ws_frame->next_bytes);
				} elsif ( $ws_frame->is_binary ) {
					print STDERR $self->{_handle}->{id} . ' ' . $self->{_class} . " on_binary triggered.\n" if SOCKET_FRAME_DEBUG;
					$self->on_binary($ws_frame->next_bytes);
				} elsif ( $ws_frame->is_close ) {
					print STDERR $self->{_handle}->{id} . ' ' . $self->{_class} . " on_close triggered.\n" if SOCKET_FRAME_DEBUG;
					$self->on_close($ws_frame->next_bytes);	
				} elsif ( $ws_frame->is_ping ) {
					print STDERR $self->{_handle}->{id} . ' ' . $self->{_class} . " on_ping triggered.\n" if SOCKET_FRAME_DEBUG;
					$self->on_ping($ws_frame->next_bytes);
				} elsif ( $ws_frame->is_pong ) {
					print STDERR $self->{_handle}->{id} . ' ' . $self->{_class} . " on_pong triggered.\n" if SOCKET_FRAME_DEBUG;
					$self->on_pong($ws_frame->next_bytes);
				} elsif ( $ws_frame->is_continuation ) {
					print STDERR $self->{_handle}->{id} . ' ' . $self->{_class} . " on_continuation triggered.\n" if SOCKET_FRAME_DEBUG;
				}
			});
			$self->on_open();
			return $self;
		}
		return undef;
  	}
}
	
sub encoding {
	my $self = shift;
	my $input = shift;
	if ($input && $input eq 'json' ) {
		print STDERR $self->{_handle}->{id} . ' ' . $self->{_class} . " transport encoding set to json.\n"  if SOCKET_DEBUG;
		my $json = JSON::XS->new->utf8;
		$self->{_encode} = sub { return $json->encode(shift); };
		$self->{_decode} = sub { my ($input) = shift; return $json->decode($input) if $input; return {}; };
		$self->{_on_message} = sub { 
			$self->on_message($json->decode(shift) || {});
		};
		$self->{_send} = sub {
			my $message = $self->{_frame}->new( 
				buffer => $json->encode(shift || {}), 
				type  => 'text'
			)->to_bytes;
			$self->{_handle}->push_write($message) if $message && $self->{_handle};
		};
		$self->{_send_raw} = sub {
			my $message = $self->{_frame}->new( 
				buffer => shift, 
				type  => 'text'
			)->to_bytes;
			$self->{_handle}->push_write($message) if $message && $self->{_handle};
		};
		$self->{encoding} = 'json';
	} elsif ( $input && $input eq 'msgpack' ) {
		print STDERR $self->{_handle}->{id} . ' ' . $self->{_class} . " transport encoding set to msgpack.\n"  if SOCKET_DEBUG;
		my $msgpack_stream 	= Data::MessagePack::Stream->new;
		my $msgpack			= Data::MessagePack->new->utf8->prefer_integer;
		binmode($self->{_handle}->{fh});
		$self->{_encode} = sub { return $msgpack->pack(shift); };
		$self->{_decode} = sub { return $msgpack->unpack(shift); };
		$self->{_on_message} = sub {
			$msgpack_stream->feed(shift);
			while ( $msgpack_stream->next ) {
				$self->on_message($msgpack_stream->data || {});
			}
		};
		$self->{_send} = sub {
			my $message = $self->{_frame}->new( 
				buffer => $msgpack->pack(shift), 
				type  => 'binary'
			)->to_bytes;
			$self->{_handle}->push_write($message) if $message && $self->{_handle};
		};
		$self->{_send_raw} = sub {
			my $message = $self->{_frame}->new( 
				buffer => shift, 
				type  => 'binary'
			)->to_bytes;
			$self->{_handle}->push_write($message) if $message && $self->{_handle};
		};
		$self->{encoding} = 'msgpack';
	}
	return $self->{encoding};
}	
sub on_text {
	my $self = shift;
	my $text = shift;
	$self->{_on_message}->($text) if $text;
}
sub on_binary {
	my $self = shift;
	my $binary = shift;
	$self->{_on_message}->($binary) if $binary;
}
sub encode {
	my $self  = shift;
	return $self->{_encode}->(shift) || '';
}
sub decode {
	my $self  = shift;
	return $self->{_decode}->(shift) || {};
}
sub send {
	my $self    = shift;
	$self->{_send}->(shift);
}
sub send_raw {
	my $self = shift;
	$self->{_send_raw}->(shift);
}
sub on_ping {}
sub on_pong {}
sub on_open {
	my $self = shift;
	print STDERR $self->{_handle}->{id} . ' ' . $self->{_class} . " in on_open.\n" if SOCKET_DEBUG;
}


sub on_error {
	my $self = shift;
	my $input = shift;
	print STDERR $self->{_handle}->{id} . ' ' . $self->{_class} . " in on_error.\n$input" if SOCKET_DEBUG;
}
sub on_message {}
sub on_authenticate {
	my $self = shift;
	my $input = shift;
	print STDERR $self->{_handle}->{id} . ' ' . $self->{_class} . " in on_authenticate.\n" if SOCKET_DEBUG;
	$self->{_authenticated} = 1;
	$self->{_handle}->timeout( $self->{auth_idle_timeout} );
	$self->{_handle}->rbuf_max( $self->{auth_rbuf_max} );
	$self->{_handle}->wbuf_max( $self->{auth_wbuf_max} );
}
sub on_unimplemented {
	my $self  = shift;
	my $input = shift;
	print STDERR $self->{_handle}->{id} . ' ' . $self->{_class} . " in on_unimplemented with event: " . Dumper(\$input);
};
	
sub authenticated {
	my $self  = shift;
	my $input = shift;
	if ( $input && !$self->{_authenticated} ) {
		$self->on_authenticate($input);
	}
	return $self->{_authenticated};
}
sub on_close {
	my $self = shift;
	print STDERR $self->{_handle}->{id} . ' ' . $self->{_class} . " in on_close.\n" if SOCKET_DEBUG;
	$self->{_handle}->push_shutdown();
	undef $self;
}
sub handle {
	my $self     = shift;
	return $self->{_handle};
}
sub connId {
	my $self     = shift;
	return $self->{_handle}->{id};
}
sub ra2h {
	my $self     = shift;
	my $input    = shift;
	my $rowcount = 0;
	my $key      = '';
	my $output   = {};
	foreach my $value ( @{$input} ) {
		if ( $rowcount++ % 2 == 0 ) {
			$key = $value;
		} else {
			$output->{$key} = $value || '';
		}
	}
	return $output;
}
sub DESTROY {
	my $self = shift;
	$self->on_close();
}

1;
