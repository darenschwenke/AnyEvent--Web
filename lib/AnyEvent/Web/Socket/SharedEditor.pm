package AnyEvent::Web::Socket::SharedEditor;

use parent qw( AnyEvent::Web::Socket );
use AnyEvent::Redis::RipeRedis;

use constant JQ_DEBUG => 1;

use Data::Dumper;

sub new {
	my ( $caller, $handle, $config ) = @_;
	my $class = ref($caller) || $caller;
	my $self = $class->SUPER::new( $handle, $config );
	$self->{username} = $self->connId if !$self->{username};
	return $self;
}

sub on_message {
	my $self  = shift;
	my $input = shift;
	$input->{eventName} ||= '';
	if ( $input->{eventName}
		 && ( my $method = $self->can( 'on_' . $input->{eventName} ) ) )
	{
		print STDERR 'WebSocket on_'
		  . $input->{eventName}
		  . ' triggered with:'
		  . Dumper($input)
		  if JQ_DEBUG;
		$method->( $self, $input );
	} elsif ( my $method = $self->can('on_unimplemented') ) {
		$method->( $self, $input );
	}
}

sub on_open {
	my $self  = shift;
	my $input = shift;
	$self->{redis} = {
		   eventRecv =>
			 AnyEvent::Redis::RipeRedis->new( %{ $config->{redis}->{events} } ),
		   eventSend =>
			 AnyEvent::Redis::RipeRedis->new( %{ $config->{redis}->{events} } ),
		   state =>
			 AnyEvent::Redis::RipeRedis->new( %{ $config->{redis}->{state} } )
	};
}

sub on_login {
	my $self  = shift;
	my $input = shift;
	$self->authenticated(1);
	$self->{username} = $input->{username} || '';
	$self->{room_id}  = $input->{room_id}  || 'default';
	$self->{redis}->{eventRecv}->subscribe(
		'user:' . $self->connId,
		{
		   on_message => sub {
			   my ( $channel, $message ) = @_;
			   print STDERR 'redis on_message channel => '
				 . $channel
				 . ', message => '
				 . $message . "\n"
				 if JQ_DEBUG;
			   $self->send_raw($message);
			 }
		}
	);
	$self->send(
			{
			  eventName => "jQuery",
			  data      => [
					 {
					   t => '#messages',
					   a => 'append',
					   c => '<li><b>System</b><p>Connected to Server.</p></li>'
					 },
					 {
					   t => '#messages',
					   a => 'append',
					   c => '<li><b>System</b><p>Joining room "'
						 . $self->{room_id}
						 . '".</p></li>'
					 }
			  ]
			}
	);
	$self->{redis}->{state}->hset(
		'room_users:' . $self->{room_id},
		$self->connId,
		$input->{username},
		{
		   on_done => sub {
			   $self->{redis}->{eventRecv}->psubscribe(
				   'room:' . $self->{room_id} . ':*',
				   {
					  on_done => sub {
						  $self->{redis}->{eventSend}->publish(
							  'room:' . $self->{room_id} . ':all',
							  $self->encode(
									  {
										eventName => 'jQuery',
										data      => [
											 {
											   t => '#messages',
											   a => 'append',
											   c => '<li><b>System</b><p>User '
												 . $self->{username}
												 . ' joined the room.</p></li>'
											 },
										]
									  }
							  ),
							  {
								 on_done => sub {
									 $self->on_getRoomUsers(
											  { room_id => $self->{room_id} } );
									 $self->{redis}->{state}->smembers(
										 'room_editors:' . $self->{room_id},
										 {
											on_done => sub {
												my $editors = shift;
												if ( scalar @{$editors} ) {
													foreach
													  my $editor ( @{$editors} )
													{
														$self->{redis}
														  ->{eventSend}
														  ->publish(
															'room:'
															  . $self->{room_id}
															  . ':'
															  . $self->connId,
															$self->encode(
																{
																   eventName =>
																	 'getState',
																   id => $editor
																}
															),
															{
															   on_done => sub {

																 }
															}
														  );
													}
												} else {
													$self->on_createEditor();
												}
											},
											on_error => sub {
											  }
										 }
									 );
								   }
							  }
						  );
					  },
					  on_error => sub {
					  },
					  on_message => sub {
						  my ( $channel, $message, $pattern ) = @_;
						  return
							  if $channel eq 'room:'
							. $self->{room_id} . ':'
							. $self->connId;
						  print STDERR "Sending to " . $self->connId . "\n";
						  $self->send_raw($message);
						}
				   }
			   );
			 }
		}
	);
}

sub on_createEditor {
	my $self  = shift;
	my $input = shift;
	$editor_id = 'e' . join '',
	  map +( 0 .. 9, 'a' .. 'k', 'm' .. 'z', 'A' .. 'H', 'J' .. 'Z' )
	  [ rand( 10 + 25 * 2 ) ], 1 .. 7;
	$self->{redis}->{state}->sadd(
		'room_editors:' . $self->{room_id},
		$editor_id,
		{
		   on_done => sub {
			   $self->send( { eventName => 'newEditor', id => $editor_id } );
			 }
		}
	);
}

sub on_getRoomUsers {
	my $self     = shift;
	my $input    = shift;
	my $callback = shift || sub { };
	$self->{redis}->{state}->hvals(
		'room_users:' . $self->{room_id},
		{
		   on_done => sub {
			   my $users = shift;
			   $self->{redis}->{eventSend}->publish(
							'room:' . $self->{room_id} . ':all',
							$self->encode(
								{
								  eventName => 'jQuery',
								  data      => [
									   {
										 t => '#users',
										 a => 'html',
										 c => '<li>'
										   . join( '</li><br><li>', @{$users} )
										   . '</li>'
									   },
								  ]
								}
							),
							{
							  on_done => $callback,
							}
			   );
			 }
		}
	);
}

sub on_setUsername {
	my $self  = shift;
	my $input = shift;
	if ( $input->{username} && $self->{username} ne $input->{username} ) {
		$self->{redis}->{state}->hset(
			'room_users:' . $self->{room_id},
			$self->connId,
			$input->{username},
			{
			   on_done => sub {
				   $self->{redis}->{eventSend}->publish(
					   'room:' . $self->{room_id} . ':all',
					   $self->encode(
								   {
									 eventName => 'jQuery',
									 data      => [
										  {
											t => '#messages',
											a => 'append',
											c => '<li><b>System</b><p>User "'
											  . $self->{username}
											  . '" has changed thier name to "'
											  . $input->{username}
											  . '".</p></li>'
										  },
									 ]
								   }
					   ),
					   {
						  on_done => sub {
							  $self->{username} = $input->{username};
							  $self->on_getRoomUsers(
											  { room_id => $self->{room_id} } );
						  },
						  on_error => sub {
							}
					   }
				   );

			   },
			   on_error => sub {
				 }
			}
		);
	}
}

sub on_saveState {
	my $self  = shift;
	my $input = shift;
	$self->{redis}->{state}
	  ->hmset( 'room_editor:' . $self->{room_id} . ':' . $input->{id},
			   %{$input} );
}

sub on_close {
	my $self  = shift;
	my $input = shift;
	$self->{redis}->{state}->hdel(
		'room_users:' . $self->{room_id},
		$self->connId,
		{
		   on_done => sub {
			   $self->on_getRoomUsers(
				   { room_id => $self->{room_id} },
				   sub {
					   $self->{redis}->{eventSend}->publish(
						   'room:' . $self->{room_id} . ':all',
						   $self->encode(
									  {
										eventName => 'jQuery',
										data      => [
											 {
											   t => '#messages',
											   a => 'append',
											   c => '<li><b>System</b><p>User '
												 . $self->connId
												 . ' left the room.</p></li>'
											 },
										]
									  }
						   ),
						   {
							 on_done  => sub { },
							 on_error => sub { }
						   }
					   );
					   $self->{redis}->{eventRecv}->unsubscribe(
						   'user:' . $self->connId,
						   {
							 on_done  => sub { },
							 on_error => sub { }
						   }
					   );
					   $self->{redis}->{eventRecv}->punsubscribe(
						   'room:' . $self->{room_id} . ':*',
						   {
							 on_done  => sub { },
							 on_error => sub { }
						   }
					   );

				   }
			   );
			 }
		}
	);
	$self->SUPER::on_close();
}

sub on_applyDeltas {
	my $self  = shift;
	my $input = shift;
	my $id    = $self->connId;
	$id = 'all' if $input->{sendSelf};
	print STDERR "Publishing to ui:$id\n";
	$self->{redis}->{eventSend}->publish(
		'room:' . $self->{room_id} . ':' . $id,
		$self->encode($input),
		{
		  on_done  => sub { },
		  on_error => sub { }
		}
	);
}

sub on_newEditor {
	my $self  = shift;
	my $input = shift;
	my $id    = $self->connId;
	$id = 'all' if $input->{sendSelf};
	print STDERR "Publishing to ui:$id\n";
	$self->{redis}->{eventSend}->publish(
		'room:' . $self->{room_id} . ':' . $id,
		$self->encode($input),
		{
		  on_done  => sub { },
		  on_error => sub { }
		}
	);
}

sub on_setFilename {
	my $self  = shift;
	my $input = shift;
	my $id    = $self->connId;
	$id = 'all' if $input->{sendSelf};
	print STDERR "Publishing to ui:$id\n";
	$self->{redis}->{eventSend}->publish(
		'room:' . $self->{room_id} . ':' . $id,
		$self->encode($input),
		{
		  on_done  => sub { },
		  on_error => sub { }
		}
	);
}

sub on_setContext {
	my $self  = shift;
	my $input = shift;
	my $id    = $self->connId;
	$id = 'all' if $input->{sendSelf};
	print STDERR "Publishing to ui:$id\n";
	$self->{redis}->{eventSend}->publish(
		'room:' . $self->{room_id} . ':' . $id,
		$self->encode($input),
		{
		  on_done  => sub { },
		  on_error => sub { }
		}
	);
}

sub on_setTheme {
	my $self  = shift;
	my $input = shift;
	my $id    = $self->connId;
	$id = 'all' if $input->{sendSelf};
	print STDERR "Publishing to ui:$id\n";
	$self->{redis}->{eventSend}->publish(
		'room:' . $self->{room_id} . ':' . $id,
		$self->encode($input),
		{
		  on_done  => sub { },
		  on_error => sub { }
		}
	);
}

sub on_sendMessage {
	my $self  = shift;
	my $input = shift;
	my $id    = $self->connId;
	$id = 'all' if $input->{sendSelf};
	$self->{redis}->{eventSend}->publish(
		'room:' . $self->{room_id} . ':' . $id,
		$self->encode(
					   {
						 eventName => 'jQuery',
						 data      => [
								   {
									 t => '#messages',
									 a => 'append',
									 c => '<li><b>'
									   . $input->{from}
									   . '</b><p>'
									   . $input->{message}
									   . '</p></li>'
								   },
						 ]
					   }
		),
		{
		  on_done  => sub { },
		  on_error => sub { }
		}
	);
}

1;
