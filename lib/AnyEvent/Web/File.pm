package AnyEvent::Web::File;

use Data::Dumper;
use AnyEvent::IO;
use AnyEvent::Web::Util qw(time2str);
use File::Basename;
use File::MimeInfo;
use File::MimeInfo::Magic qw(magic);
use Scalar::Util qw(weaken isweak);
use constant FILE_DEBUG => 1;
use constant FILE_CACHE_DEBUG => 1;

use URI::Escape qw( uri_unescape );

sub new {
	my ($caller,$config) = @_;
	my $class = ref($caller) || $caller;
	my $self = { 
		web_root => undef,
		cache_enable => 0,
		cache_expire => 300,
		file_at_once_max => 32 * 1024,
		blocksize => 4096,
		server_name => 'AnyEvent::Web',
		now => time(),
		now_http=> time2str(),
		mime_map => { 
			css 	=> 'text/css',
			jpg		=> 'image/jpeg',
			png		=> 'image/png',
			js 		=> 'text/javascript',
			htm 	=> 'text/html ; charset=utf-8',
			html	=> 'text/html ; charset=utf-8',
			mp3		=> 'audio/mpeg'
		},
		%{$config},
		_cache => {},
	};
	bless $self,$class;
	print STDERR "$class starting with config: " . Dumper(\$config) if FILE_DEBUG;
	#print STDERR "$class using IO module: $AnyEvent::IO::MODEL\n";
	die($class . ': web_root is not set.') if ( ! $self->{web_root} );
	die($class . ': web_root => "' . $self->{web_root} . '" does not exist.') if ( ! -d $self->{web_root} );
	die($class . ': 404 error doc =>  "' . $self->{web_root} . '/404.html" is not readable.') if ( ! -r $self->{web_root} . '/404.html' );
	$self->{_update_timer} = AnyEvent->timer ( after => 2, interval => 2, cb => sub { 
		$self->{now} = time();
		$self->{now_http} = time2str($self->{now});
		foreach my $key (keys %{$self->{_cache}} ) {
			if ($self->{_cache}->{$key}->{expires} < $self->{now} ) {
				print STDERR "Expiring cache: $key\n" if FILE_CACHE_DEBUG;
				delete($self->{_cache}->{$key}); 
			}
		}
	});
	return $self;
}

sub serve {
	my ($self,$handle) = @_;
	my $r = $handle->{request};
	$r->{keep_alive} = 1 if $r->{HTTP_CONNECTION} =~ /keep-alive/io;
	$r->{protocol} = $r->{SERVER_PROTOCOL};
	$r->{filename} ||= $self->{web_root} . $r->{PATH};
	my $key = 'PA:' . $r->{PATH} . '|' . 'KA:' . $r->{keep_alive};
	if ($self->{cache_enable} && ( $cache = $self->{_cache}->{$key}) && $cache->{size} ) {
		print STDERR "Serving $r->{PATH} from cache via rule $r->{ROUTE}\n" if FILE_DEBUG;
		$r->{content_string} = $cache->{content_string};
		$r->{rewrite}->($r) if $r->{rewrite};
		use bytes;
		$handle->push_write($cache->{header_string} . 
			'Content-Length: ' . length $r->{content_string} . "\n" . 
			'Date: ' . $self->{now_http} . "\n\n" . $cache->{content_string});
		$handle->on_drain( sub {
			$cache->{on_done}->($handle) if $cache->{on_done};
		});
		return;
	} else {
		print STDERR "Serving $r->{PATH} from filesystem via rule $r->{ROUTE}\n" if FILE_DEBUG;
	aio_open $r->{filename}, AnyEvent::IO::O_RDONLY, 0, sub {
		my ($fh) = @_;
		if ( ! $fh && ! $r->{redirect} ) {
			$r->{code} = 404;
			$r->{redirect} = 1;
			$r->{message} = 'NOT FOUND';
			$r->{filename} = $self->{web_root} . '/404.html';
			return $self->serve($handle);
		} elsif ( ! $fh ) {
			$handle->push_write(
		  		"HTTP/1.1 404 NOT FOUND\nDate: " . $self->{$now} . "\nServer: " . $self->{server_name} . "\nContent-Type: text/plain\n" . 
		  		"Content-Length: 9\nLast-Modified: " . $self->{$now} . "\n\nNot Found"
		  	);
			$handle->on_drain( sub {
				$r->{on_done}->(shift) if $r->{on_done};
			});
			return;
		}
		aio_stat $fh, sub {
			@_ or return;
			$r->{size} = (stat _)[7];
			$r->{mtime} = (stat _)[9];
			$r->{chunk} ||= ( (stat _)[11] || $self->{blocksize} );
			$r->{expires} = $self->{now} + $self->{cache_expire};
			my $header = $self->get_header($r);
			if ( $r->{stream} ) {
				aio_seek $fh, $r->{start_byte}, 0, sub {
					$r->{remaining_bytes} = $r->{end_byte} - $r->{start_byte};
					$handle->on_drain(sub {
						if ( $r->{size} <= 0 || $r->{remaining_bytes} <= 0 ) {
							aio_close $fh,sub { };
							$handle->on_drain( sub {});
							$r->{on_done}->($handle) if $r->{on_done};
						} else {	
							$r->{chunk} = $r->{remaining_bytes} if $r->{remaining_bytes} < $r->{chunk};
							aio_read $fh, $r->{chunk}, sub {
								$handle->push_write(@_);
								$r->{remaining_bytes} -= $r->{chunk};
							};
						}
					});
					$handle->push_write($header);
				};
			} else {
				aio_read $fh, $r->{size}, sub {
					my ($content_string) = @_;
					aio_close $fh,sub {};
					$r->{content_string} = $content_string;
					if ( $r->{rewrite} ) {
						$r->{rewrite}->($r);
						$r->{size} = length $r->{content_string};
						$handle->push_write($self->get_header($r) . $self->get_content($r));
						$r->{content_string} = $content_string;
					} else {
						$handle->push_write($self->get_header($r) . $self->get_content($r));
					}
					$handle->on_drain(sub {
						$r->{on_done}->(shift) if $r->{on_done};
						$handle->on_drain( sub {} );
						return;
					});
					if ( $self->{cache_enable} && ! $r->{cache_disable} ) {
						$self->{_cache}->{$key} = $r;
					} 
				};
			}
   	   	};
	};
	}
}

sub on_error {
	my $self = shift;
	my $r = $self->get_inline(@_);
	return get_header($r) . get_content($r);
}

sub get_inline {
	my ($self,$code,$message,$mime_type,$content_string,$r) = @_;
	$r = {} if ! $r;
	$r = {
		%{$r}, 
		code => ($code || 404),
		message => ($message || 'NOT FOUND'),
		content_string => ($content_string || $message ),
		mime_type => ($mime_type || 'text/plain')
	};
	$r->{size} = length $r->{content_string};
	return $r;
}
		
sub clear_cache {
	my $self = shift;
	foreach my $key (keys %{$self->{_cache}} ) {
		weaken($self->{_cache}->{$key});
	}
}
sub get_header {
	my ($self,$r) = @_;
	my $partial = '';
	if ( ! $r->{header_string} ) {
		if ( $r->{size} > $self->{file_at_once_max} ) {
			$r->{stream} = 1;
			$r->{cache_disable} = 1;
		}
		$r->{mtime} ||= $self->{now};
		if ( $r->{HTTP_RANGE} && $r->{HTTP_RANGE} =~ /bytes=(\d*)-(.*)$/io ) {
			$r->{code} ||= 206;
			$r->{message} = 'PARTIAL CONTENT';
			$r->{start_byte} = $1;
			$r->{end_byte} = $2 || $r->{size};
			$r->{stream} = 1;
			$r->{cache_disable} = 1;
			$partial = 'Content-Range: bytes ' . $r->{start_byte} . '-' . $r->{end_byte} . '/' . $r->{size} . "\n";
		} else {
			$r->{code} ||= 200;
			$r->{keep-alive} = 1;
			$r->{message} ||= 'OK';
			$r->{start_byte} = 0;
			$r->{end_byte} = $r->{size};
		}
		if ( ! $r->{mime_type} ) {
			($r->{fileext}, $r->{filepart},undef ) = reverse(split /\./, $r->{PATH});
			$r->{mime_type} = $self->{mime_map}->{$r->{fileext}} if $self->{mime_map}->{$r->{fileext}};
			$r->{mime_type} = magic($r->{filename}) if ! $r->{mime_type};
		}
		$r->{header_string} = $r->{protocol} . ' ' . $r->{code} . ' ' . $r->{message} . "\n" . 
			'Last-Modified: ' . time2str($r->{mtime}) . "\n" .
			'Server: ' . $self->{server_name} . "\n" . 
			'Accept-Ranges: bytes' . "\n" .  
			'Content-Type: ' . $r->{mime_type} . "\n" .
			'Cache-Control:	max-age=' . ($self->{max_age} || $self->{cache_expire} || 1800) . "\n" .
			$partial;
		if ( $r->{HTTP_CONNECTION} =~ /keep-alive/io ) { #|| $r->{SERVER_PROTOCOL} eq 'HTTP/1.1' ) {
			$r->{header_string} .= 'Connection: Keep-Alive' . "\n" .
			'Keep-Alive: timeout=' . ( $r->{timeout} || 5 ) . "\n";
		} else {
			$r->{keep-alive} = 0;
			$r->{on_done} = sub {
				my ( $handle ) = shift;
				$handle->push_shutdown() if $handle;
			}
		}
	}
	return $r->{header_string} . 
		'Content-Length: ' . $r->{size} . "\n" . 
		'Date: ' . $self->{now_http} . "\n" . "\n";
}
sub get_content {
	my ($self,$r) = @_;
	return $r->{content_string};
}	

1;