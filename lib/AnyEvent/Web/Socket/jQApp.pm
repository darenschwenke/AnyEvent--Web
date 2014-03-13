package AnyEvent::Web::Socket::jQApp;

use parent qw( AnyEvent::Web::Socket );
use AnyEvent::Redis::RipeRedis;

use Data::Dumper;

sub new {
	my ($caller,$handle,$config) = @_;
	my $class = ref($caller) || $caller;
    my $self = $class->SUPER::new($handle,$config);
    return $self;
}

sub on_message {
	my $self = shift;
	my $input = shift;
	$input->{eventName} ||= '';
	if ( $input->{eventName} && $self->can('on_' . $input->{eventName}) ) {
		$self->can('on_' . $input->{eventName})->($self,$input);
	} else {
		$self->can('on_unimplemented')->($self,$input) if $self->can('on_unimplemented');
	}
}
sub on_open {
	my $self  = shift;
	my $input = shift;
    $self->{redis} = {
    	eventRecv => AnyEvent::Redis::RipeRedis->new( %{ $config->{redis}->{events} } ), 
    	eventSend => AnyEvent::Redis::RipeRedis->new( %{ $config->{redis}->{events} } ),
    	state => AnyEvent::Redis::RipeRedis->new( %{ $config->{redis}->{state} } )
    };
	$self->authenticated(1);
	$self->{redis}->{eventRecv}->subscribe(
		'user:' . $self->connId ,
		{ 
			on_message => sub {
				my ($channel,$message) = @_;
				$self->send($message);
			}
		}
	);
};

sub on_login {
	my $self  = shift;
	my $input = shift;
	$self->is_authenticated(1);
	$self->send({eventName=>"login",data => {t=>'#messages',a=>'append',c=>'<div><b>Connection</b>&nbsp;&nbsp;Connected to WebSocket.</div>' }});
	$self->{redis}->{eventRecv}->psubscribe(
		'ui:*',
		{ 
			on_done => sub {},
			on_error => sub {},
			on_message => sub {
				my ($channel,$message,$pattern) = @_;
				return if $channel eq 'ui:' . $self->connId;
				$self->send($message);
			}
		}
	);
}

sub on_drawLine {
	my $self  = shift;
	my $input = shift;
	my @data;
	$self->{redis}->{eventSend}->publish(
		'ui:' . $self->connId,
		$self->encode({data=>{e=>'drawLine(' . $self->encode($input->{coordinates}) . ')'}}),
		{
		  on_done  => sub {},
		  on_error => sub {}
		}
	);
}

sub on_sendMessage {
	my $self  = shift;
	my $input = shift;
	my $id = $self->connId;
	$id = 'all' if $input->{sendSelf};
	my @data;
	$self->{redis}->{eventSend}->publish(
		'ui:' . $id,
		$self->encode({
			data=>[
				{t=>'#messages', a=>'append', c=>'<div><b>' . $input->{from} . '</b>&nbsp;&nbsp;' . $input->{message} . '</div>' } ,  
				# maps to $('#messages').append('<b...');
				# {a=>'append',c=>'Something else!<br />' } 
				# No t variable (target) maps to chaining from previous.
			]
		 }
		),
		{
		  on_done  => sub {},
		  on_error => sub {}
		}
	);
}

1;
