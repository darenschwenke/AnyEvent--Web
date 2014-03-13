package AnyEvent::Web::WAMP::Constants;

BEGIN { AnyEvent::common_sense }

use base 'Exporter';

our @EXPORT = qw(
  	msg2code code2msg 
);
our $VERSION = '0.0.2';

our $_MSG2CODE = {
	HELLO => 1,
	WELCOME => 2,
	ABORT => 3,
	CHALLENGE => 4,
	AUTHENTICATE => 5,
	GOODBYE => 6,
	HEARTBEAT => 7,
	ERROR		=> 8,
	PUBLISH		=> 16,
	PUBLISHED	=> 17,
	SUBSCRIBE	=> 32,
	SUBSCRIBED	=> 33,
	UNSUBSCRIBE	=> 34,
	UNSUBSCRIBED => 35,
	EVENT		=> 36,
	CALL		=> 48,
	CANCEL		=> 49,
	RESULT		=> 50,
	REGISTER	=> 64,
	REGISTERED	=> 65,
	UNREGISTER	=> 66,
	UNREGISTERED=> 67,
	INVOCATION	=> 68,
	INTERRUPT	=> 69,
	YIELD		=> 79
};

our $_CODE2MSG = reverse $_MSG2CODE;

sub msg2code {
	my $msg = shift;
	return $_MSG2CODE->{$msg} if defined($_MSG2CODE->{$msg} );
	return undef;
}
sub code2msg {
	my $code = shift;
	return $_CODE2MSG->{$code} if defined($_CODE2MSG->{$code} );
	return undef;
}

1;