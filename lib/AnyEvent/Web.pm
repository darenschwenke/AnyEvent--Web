package AnyEvent::Web;

BEGIN { AnyEvent::common_sense }

use Data::Dumper;

use FindBin;
use lib "$FindBin::Bin/../";
use HTTP::Parser::XS qw(parse_http_request);
#use URI::Escape qw( uri_unescape );

use AnyEvent::Handle;
use AnyEvent::Socket qw( tcp_server );
use AnyEvent::Web::Util qw( time2str );
use constant ROUTE_DEBUG => 0;

use base 'Exporter';

our @EXPORT = qw(
);
our $VERSION = '0.0.3';
our $PATH_CLEAN_REGEX = qr{\.\.\/}s;
our $PATH_UNESCAPE_REGEX = qr{%([0-9A-Fa-f]{2})};

sub new {
	my ($caller,$config,$routes) = @_;
	my $class = ref($caller) || $caller;
	my $self = bless {
		config => $config || { server_id => 0 },
		routes => $routes || [],
		_connections => {},
		_tcp_server => undef,
	}, $class;
	#print STDERR "$class using Event model: $AnyEvent::MODEL\n";
	return $self;
}

sub serve {
	my $self = shift;
	print STDERR 'Listen ' . $self->{config}->{bind_ip} . ':' .  $self->{config}->{bind_port} . "\n";
	$self->{_tcp_server} = AnyEvent::Socket::tcp_server(
		$self->{config}->{bind_ip}, 
		$self->{config}->{bind_port}, 
		sub {
			my ($sock) = shift;
			#my ($sock, $host, $port) = @_;
			my $id =  (10000000 * $self->{config}->{server_id}) + fileno($sock);
			$self->{_connections}->{$id} = AnyEvent::Handle->new(
				fh => $sock, 
				id => $id,
    			server_name => 'AnyEvent::Web',
    			request => {},
				on_error => sub {
					my ($handle,$fatal,$error) = @_;
					print STDERR "$id got error $error\n" if ROUTE_DEBUG;
					$handle->destroy() if $fatal;
				},
				on_eof => sub {
					my ($handle) = shift;
					print STDERR "$id got eof\n" if ROUTE_DEBUG;
					$handle->destroy();
				},	
				on_timeout => sub {
					my ($handle) = shift;
					print STDERR "$id got timeout\n" if ROUTE_DEBUG;
					$handle->destroy();
				},
				on_read => sub {
					my ($handle) = shift;
					my $r = {}; # if ! $handle->{request};
					my $ret = parse_http_request($handle->{rbuf},$r);
					if ($ret == -1) {
						print STDERR "$id bad request\n" if ROUTE_DEBUG;
						my $now = time2str();
		  				$handle->push_write(
		  					"HTTP/1.1 400 BAD REQUEST\nDate: $now\nServer: $self->{server_name}\nContent-Type: text/plain\n" . 
		  					"Content-Length: 11\nLast-Modified: $now\nExpires: $now\n\nBad Request"
		  				);
						$handle->push_shutdown();
					} elsif ($ret == -2) {
						print STDERR "$id incomplete request\n" if ROUTE_DEBUG;
		  			} else {
		  				$handle->{request} = $r;
						$r->{PATH} = $r->{PATH_INFO};
						$r->{PATH} = '/index.html' if $r->{PATH} eq '/';
						$r->{PATH} =~ s/$PATH_UNESCAPE_REGEX/chr(hex($1))/eg;
						$r->{PATH} =~ s/$PATH_CLEAN_REGEX//g;
						ROUTE:
						foreach my $route ( @{ $self->{routes} } ) {
							$r->{ROUTE} = $route->{name};
							$r->{CONTINUE} = 0;
							print STDERR "$id $r->{PATH} checking route $route_num -> $route->{name}\n" if ROUTE_DEBUG;
							if ( defined ( $route->{match_path} ) && $r->{PATH} eq $route->{match_path} ) {
								$route->{handler}->($handle) if $route->{handler};
								last ROUTE if ! $r->{CONTINUE};
							}
							if ( defined ( $route->{match_any} ) ) {
								foreach my $key ( keys %{$route->{match_any}} ) {
									if ( defined($r->{$key}) && $r->{$key} ~~ $route->{match_any}->{$key}) {
					 					$r->{VARS}->{$key} = %+ if %+;
										$route->{handler}->($handle) if $route->{handler};
										last ROUTE if ! $r->{CONTINUE};
									}
								}
							} elsif ( defined ( $route->{match_all} ) ) {
								MATCH_ALL: {
									foreach my $key ( keys %{$route->{match_all}} ) {
										if ( defined($r->{$key}) ) {
											if ( $r->{$key} ~~ $route->{match_all}->{$key} ) {
					 							$r->{VARS}->{$key} = %+ if %+;
											} else {
												last MATCH_ALL;
											} 
										} else {
											last MATCH_ALL;
										}
									}
									$route->{handler}->($handle) if $route->{handler};
									last ROUTE if ! $r->{CONTINUE};
								}
							} elsif ( defined ( $route->{match_none} ) ) {
								MATCH_NONE: {
									foreach my $key ( keys %{$route->{match_none}} ) {
										if ( defined($r->{$key}) ) {
											if ( $r->{$key} ~~ $route->{match_none}->{$key} ) {
												last MATCH_NONE;
											}
										}
									}
									$route->{handler}->($handle) if $route->{handler};
									last ROUTE if ! $r->{CONTINUE};
								}
							} elsif ( defined ( $route->{handler} ) ) {
								$route->{handler}->($handle);
								last ROUTE if ! $r->{CONTINUE};
							}
						}
						$handle->{rbuf} = undef;
		  			}
				},
				routes => $self->{routes} || [],
				%{$self->{config}}
			);
		}
	);
}

sub parse_form {
	my $self = shift;
	my $r = shift;
	if ( $r->{REQUEST_METHOD} eq 'GET' && $r->{QUERY_STRING} ) {
  		foreach my $var (split(/&/, $r->{QUERY_STRING})) {
  			my ( $name, $value ) = split(/=/,$var);
  			if ( ! defined ($r->{FORM}->{$name} ) ) {
  				$r->{FORM}->{$name} = [];
  			}
  			push(@{$r->{FORM}->{$name}},uri_unescape($value));
  		}
  	}
  	return $r->{FORM};
}

1;
