package AnyEvent::Web::Socket::jQApp;

use parent qw( AnyEvent::Web::Socket );
use AnyEvent::Redis::RipeRedis;

use constant JQ_DEBUG => 1;

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
	if ( $input->{eventName} && ( my $method = $self->can('on_' . $input->{eventName}) ) ) {
		print STDERR 'WebSocket on_' . $input->{eventName} . ' triggered with:' . Dumper($input) if JQ_DEBUG;
		$method->($self,$input);
	} elsif ( my $method = $self->can('on_unimplemented') ) {
		$method->($self,$input);
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
				print STDERR 'redis on_message channel => ' . $channel . ', message => ' . $message . "\n" if JQ_DEBUG;
				$self->send_raw($message);
			}
		}
	);
	$self->send({eventName=>"login",data => {t=>'#messages',a=>'append',c=>'<li><b>Connection</b>Connected to WebSocket.</li>' }});
	$self->{redis}->{eventRecv}->psubscribe(
		'ui:*',
		{ 
			on_done => sub {},
			on_error => sub {},
			on_message => sub {
				my ($channel,$message,$pattern) = @_;
				return if $channel eq 'ui:' . $self->connId;
				$self->send_raw($message);
			}
		}
	);
	$self->{redis}->{eventSend}->publish(
		'ui:all',
		$self->encode({
			data=>[
				{t=>'#messages', a=>'append', c=>'<li><b>System</b>User ' . $self->connId . ' joined the room.</li>' } ,  
			]
		 }
		),
		{
		  on_done  => sub {},
		  on_error => sub {}
		}
	);
};

sub on_close {
	my $self  = shift;
	my $input = shift;
	$self->{redis}->{eventSend}->publish(
		'ui:all',
		$self->encode({
			data=>[
				{t=>'#messages', a=>'append', c=>'<li><b>System</b>User ' . $self->connId . ' left the room.</li>' } ,  
			]
		 }
		),
		{
		  on_done  => sub {},
		  on_error => sub {}
		}
	);
	$self->SUPER::on_close();
}

sub on_drawLine {
	my $self  = shift;
	my $input = shift;
	print STDERR 'on_drawLine got :' . Dumper($input) if JQ_DEBUG;
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
	$self->{redis}->{eventSend}->publish(
		'ui:' . $id,
		$self->encode({
			data=>[
				{t=>'#messages', a=>'append', c=>'<li><b>' . $input->{from} . '</b>' . $input->{message} . '</li>' } ,  
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
