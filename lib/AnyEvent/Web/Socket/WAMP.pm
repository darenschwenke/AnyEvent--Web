package AnyEvent::Web::Socket::WAMP;

use parent qw( AnyEvent::Web::Socket );
use AnyEvent::Redis::RipeRedis;
use AnyEvent::Web::Socket::WAMP::Constants qw(msg2code code2msg);

use Data::Dumper;

sub new {
	my ($caller,$handle,$config) = @_;
	my $class = ref($caller) || $caller;
    my $self = $class->SUPER::new($handle,
    {
    	features => {
    		agent => "AnyEvent::Web::WAMP",
    	},
    	%{$config}
    });
    return $self;
}

sub on_open {
	my ($self,$input) = @_;
	$self->{redis} = {
    	eventRecv => AnyEvent::Redis::RipeRedis->new( %{ $config->{redis}->{events} } ), 
    	eventSend => AnyEvent::Redis::RipeRedis->new( %{ $config->{redis}->{events} } ),
    	state => AnyEvent::Redis::RipeRedis->new( %{ $config->{redis}->{state} } )
    };
	$self->{redis}->{eventRecv}->subscribe(
		'user:' . $self->connId ,
		{ 
			on_message => sub {
				my ($channel,$message) = @_;
				$self->send($message);
			}
		}
	);
	$self->SUPER::on_open($input);
};

sub on_message {
	my $self = shift;
	my $input = shift;
	if ( ref($input) eq 'ARRAY' && (my $msgtype = code2msg(shift @{$input}) ) ) {
		if (my $method = $self->can('on_' . lc($msgtype) ) ) {
			$method->($self,@{$input});
		} else {
			$self->can('on_unimplemented')->($self,$input) if $self->can('on_unimplemented');
		}
	}
}

sub on_hello {
	my $self = shift;
	if ( $self->{hello} ) {
		$self->on_close();
	} elsif (my $method = $self->can('challenge') ) {
		$self->{hello} = 1;
		$method->($self,@_);
	} else {
		$self->{realm} = shift;
		$self->{hello} = shift;
		$self->welcome(@_);
	}
}
sub on_heartbeat {
	my $self = shift;
	my $in_seq = shift;
	my $self->{heartbeat} = shift;
}

sub welcome {
	$self->authenticated(1);
	$self->send([msg2code('WELCOME'),$self->connID,$self->{features} || {}]);
}

sub abort {
	my $self = shift;
	my $details = shift || {};
	my $reason = shift || "wamp.error.no_such_realm";
	$self->send([msg2code('ABORT'),$details,$reason]);
}

sub on_room_leave {
	my $self  = shift;
	my $input = shift;
	my $room_id = $input->{data}->{room} || 0;
	$self->{redis}->{eventSend}->publish( 'room:' . $room_id, 
		$self->encode({ 
			eventName => 'remove_peer_connected',
			data => { 
				socketId => $self->connId 
			}
		}),
		{
			on_done => sub {
				$self->{redis}->{state}->hdel('user_rooms:' . $self->connId,$room_id,{
					on_done => sub {
						$self->{redis}->{state}->hdel('room_users:' . $room_id,$self->connId,{
							on_done => sub {
								$self->{redis}->{eventRecv}->unsubscribe('room:' . $room_id);
							}
						});
					}
				});
			}
		}
	);
};

sub on_join_room {
	my $self  = shift;
	my $input = shift;
	my $room_id = $input->{data}->{room} || 0;
	$self->{redis}->{eventRecv}->subscribe('room:' . $room_id, {
		on_done => sub {
			$self->{redis}->{state}->hset('user_rooms:' . $self->connId,$room_id, 1, {
				on_done => sub {
					$self->{redis}->{state}->hkeys('room_users:' . $room_id, {
						on_done => sub {
							my $users = shift;
							$self->send({
								eventName => "get_peers",
								data => {
									connections => $users,
									you => $self->connId
								}
							});
							$self->{redis}->{state}->hset('room_users:' . $room_id,$self->connId, 1, {
								on_done => sub {
									$self->{redis}->{eventSend}->publish('room:' . $room_id,
										$self->encode({eventName => "new_peer_connected",
    		    		    				data => {
       					    	 		  		socketId => $self->connId
            								}
										})
									);
						
								}
							});
						}
					});	
				}
			});
		},
		on_message => sub {
			my ($channel,$message) = @_;
			$self->send($message);
		}
	});
}
	
sub on_send_ice_candidate {
	my $self  = shift;
	my $input = shift;
	$self->{redis}->{eventSend}->publish('user:' . $input->{data}->{socketId},
		$self->encode({
			eventName => 'receive_ice_candidate',
			data => {
				label => $input->{data}->{label},
				candidate => $input->{data}->{candidate},
				socketId => $self->connId
			}
		}),
		{
			on_done => sub {}
		}
	);
}

sub on_send_offer {
	my $self  = shift;
	my $input = shift;
	$self->{redis}->{eventSend}->publish('user:' . $input->{data}->{socketId},
		$self->encode({
			eventName => 'receive_offer',
			data => {
				sdp => $input->{data}->{sdp},
				socketId => $self->connId
			}
		}),
		{
			on_done => sub {}
		}
	);
}

sub on_send_answer {
	my $self  = shift;
	my $input = shift;
	$self->{redis}->{eventSend}->publish('user:' . $input->{data}->{socketId},
		$self->encode({
			eventName => 'receive_answer',
			data => {
				sdp => $input->{data}->{sdp},
				socketId => $self->connId
			}
		}),
		{
			on_done => sub {}
		}
	);
}
	
sub on_close {
	my $self  = shift;
	my $input = shift;
	$self->{redis}->{state}->hkeys( 'user_rooms:' . $self->connId ,{
		on_done => sub {
			my $rooms = shift;
			foreach my $room_id ( @{$rooms} ) {
				$self->on_room_leave({data => { room => $room_id} } );
			}
		}
	});
	$self->SUPER::on_close($input);
};
	
1;
 	    	
 	    	
 	    	
 	    	
 