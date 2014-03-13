package AnyEvent::Web::Socket;

use AnyEvent qw(timer);
use JSON::XS;
use Data::MessagePack;
use Data::MessagePack::Stream;
use Protocol::WebSocket::Frame;
use Protocol::WebSocket::Handshake::Server;

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
	$self->encoding($self->{encoding});
  	if (!$self->{_handshake}->is_done) {
		$self->{_handshake}->parse($self->{_handle}->{rbuf});
		$self->{_handle}->{rbuf} = undef;
		if ($self->{_handshake}->is_done) {
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
			$self->{_handle}->on_read(sub {
				my ($handle) = shift;
				$ws_frame->append($handle->{rbuf});
				$handle->{rbuf} = undef;
				if ( $ws_frame->is_text ) {
					$self->on_text($ws_frame->next_bytes);
				} elsif ( $ws_frame->is_binary ) {
					$self->on_binary($ws_frame->next_bytes);
				} elsif ( $ws_frame->is_close ) {
					$self->on_close($ws_frame->next_bytes);	
				} elsif ( $ws_frame->is_ping ) {
					$self->on_ping($ws_frame->next_bytes);
				} elsif ( $ws_frame->is_pong ) {
					$self->on_pong($ws_frame->next_bytes);
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
		my $json = JSON::XS->new->utf8;
		$self->{_encode} = sub { return $json->encode(shift); };
		$self->{_decode} = sub { my ($input) = shift; return $json->decode($input) if $input; return {}; };
		$self->{_decode_stream} = sub { my ($input) = shift; return $json->decode($input) if $input; return {}; };
		$self->{_send} = sub {
			my $message = $self->{_frame}->new( 
				buffer => $json->encode(shift), 
				type  => 'text'
			)->to_bytes;
			$self->{_handle}->push_write($message) if $message && $self->{_handle};
		};
		$self->{encoding} = 'json';
	} elsif ( $input && $input eq 'msgpack' ) {
		my $msgpack_stream 	= Data::MessagePack::Stream->new->utf8->prefer_integer;
		my $msgpack			= Data::MessagePack->new->utf8->prefer_integer;
		$self->{_encode} = sub { return $msgpack->pack(shift); };
		$self->{_decode} = sub { return $msgpack->unpack(shift); };
		$self->{_decode_stream} = sub {
			$msgpack_stream->feed(shift);
			while ( $msgpack_stream->next ) {
				$self->on_message($msgpack_stream->data || {});
			}
		};
		$self->{_send} = sub {
			my $message = $self->{_frame}->new( 
				buffer => $msgpack->pack(shift), 
				type  => 'text'
			)->to_bytes;
			$self->{_handle}->push_write($message) if $message && $self->{_handle};
		};
		$self->{encoding} = 'msgpack';
	}
	return $self->{encoding};
}	
sub on_text {
	my $self = shift;
	$self->{_decode_stream}->(shift);
}
sub on_binary {
	my $self = shift;
	$self->{_decode_stream}->(shift);
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
sub on_ping {}
sub on_pong {}
sub on_open {}
sub on_error {
	my $self = shift;
	my $input = shift;
	print STDERR $input . "\n";
}
sub on_message {}
sub on_authenticate {
	my $self = shift;
	my $input = shift;
	$self->{_authenticated} = 1;
	$self->{_handle}->timeout( $self->{auth_idle_timeout} );
	$self->{_handle}->rbuf_max( $self->{auth_rbuf_max} );
	$self->{_handle}->wbuf_max( $self->{auth_wbuf_max} );
}
sub on_unimplemented {
	my $self  = shift;
	my $input = shift;
	print STDERR $self->{_class} . " unimplemented event:" . Dumper(\$input);
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
	$self->{_handle}->push_shutdown();
	undef $self;
}
sub handle {
	my $self     = shift;
	return $self->{_handle};
}
sub connId {
	my $self     = shift;
	return $self->{_handle}->{connection_id};
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

1;
