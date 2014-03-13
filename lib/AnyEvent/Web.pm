package AnyEvent::Web;

BEGIN { AnyEvent::common_sense }

use Data::Dumper;

use FindBin;
use lib "$FindBin::Bin/../";
use HTTP::Parser::XS qw(parse_http_request);
use URI::Escape qw( uri_unescape );


use AnyEvent::Handle;
use AnyEvent::Socket qw( tcp_server );
use Socket qw( SOL_SOCKET SO_REUSEPORT ); 
use AnyEvent::Web::Util qw( time2str );


use base 'Exporter';

our @EXPORT = qw(
  	web_router 
);
our $VERSION = '0.0.3';

sub new {
	my ($caller,$config,$routes) = @_;
	my $class = ref($caller) || $caller;
	my $self = bless {
		config => $config || {},
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
			my ($sock, $host, $port) = @_;
			setsockopt($sock, SOL_SOCKET, SO_REUSEPORT, 1) or die ("Failed to set socket options: $!");
			my $id =  (10000000 * $self->{server_id}) + fileno($sock);
			$self->{_connections}->{$id} = AnyEvent::Handle->new(
				fh => $sock, 
				id => $id,
				path_regex => qr{\.\.\/}s,
    			server_name => 'AnyEvent::Web',
    			request => {},
				on_error => sub {
					my ($handle,$fatal,$error) = @_;
					$handle->destroy() if $fatal;
				},
				on_eof => sub {
					my ($handle) = shift;
					$handle->destroy();
				},	
				on_timeout => sub {
					my ($handle) = shift;
					$handle->destroy();
				},
				on_read => sub {
					my ($handle) = shift;
					$handle->{request} = {}; # if ! $handle->{request};
					my $ret = parse_http_request($handle->{rbuf},$handle->{request});
					if ($ret == -1) {
						my $now = time2str();
		  				$handle->push_write(
		  					"HTTP/1.1 400 BAD REQUEST\nDate: $now\nServer: $self->{server_name}\nContent-Type: text/plain\n" . 
		  					"Content-Length: 11\nLast-Modified: $now\nExpires: $now\n\nBad Request"
		  				);
						$handle->push_shutdown();
					} elsif ($ret == -2) {
		  			} else {
		  				my $r = $handle->{request};
  						if ( $r->{REQUEST_METHOD} eq 'GET' && $r->{QUERY_STRING} ) {
  							foreach my $var (split(/&/, $r->{QUERY_STRING})) {
  								my ( $name, $value ) = split(/=/,$var);
  								$r->{GET}->{$name} = uri_unescape($value);
  							}
  						}
						$r->{PATH} = uri_unescape($r->{PATH_INFO}) || '/';
						$r->{PATH} = '/index.html' if $r->{PATH} eq '/';
						$r->{keep_alive} = 1 if $r->{HTTP_CONNECTION} =~ /keep-alive/io;
						$r->{protocol} = $r->{SERVER_PROTOCOL};
						$r->{PATH} =~ s/$self->{path_regex}//g;
						ROUTE:
						for my $route ( @{ $handle->{routes} } ) {
							$r->{CONTINUE} = 0;
							if ( defined( $route->{match} ) ) {
								while ( my ( $var, $value ) = each %{$route->{match}} ) {
									if ( defined($handle->{request}->{$var}) && $handle->{request}->{$var} ~~ $value ) {
					 					$r->{PATH_VARS} = %+ if %+;
										if ( $route->{handler} ) {
											$route->{handler}->($handle);
											last ROUTE if ! $handle->{request}->{CONTINUE};
										}
									}
								}
							} elsif ( defined( $route->{match_all} ) ) {
								my $matched = 0;
								MATCH_ALL: {
									while ( my ( $var, $value ) = each %{$route->{match_all}} ) {
										if ( defined($handle->{request}->{$var}) ) {
											if ( $handle->{request}->{$var} ~~ $value ) {
					 							$handle->{request}->{PATH_VARS} = %+ if %+;
												$matched = 1;
											} else {
												last MATCH_ALL;
											} 
										}
									}
									if ( $matched && $route->{handler} ) {
										$route->{handler}->($handle);
										last ROUTE if ! $handle->{request}->{CONTINUE};
									}
								}
							} elsif ( defined ( $route->{handler} ) ) {
								$route->{handler}->($handle);
								last ROUTE if ! $handle->{request}->{CONTINUE};
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

1;
