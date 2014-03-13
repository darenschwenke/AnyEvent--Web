package AnyEvent::Web::Util;

BEGIN { AnyEvent::common_sense }

use base 'Exporter';

our @EXPORT = qw(
  	time2str log_add log_last log_prune
  	load_config get_config clear_config 
);
our $VERSION = '0.0.2';

our @_DoW = qw(Sun Mon Tue Wed Thu Fri Sat);
our @_MoY = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
sub time2str {
    my ($sec, $min, $hour, $mday, $mon, $year, $wday) = gmtime(shift || time());
    return sprintf("%s, %02d %s %04d %02d:%02d:%02d GMT",
		$_DoW[$wday], $mday, $_MoY[$mon], $year + 1900, $hour, $min, $sec
	);
}
sub load_config {
	my ($input)  = @_;
	my $files = [];
	if ( ref($input) eq 'ARRAY' ) {
		$files = $input;
	} else {
		 $files->[0] = $input;
	}
	foreach my $file ( @{$files} ) {
		package cfg;
		my $rc = do($file);
		if ($@) {
    		die("Failure compiling config file '$file' - $@");
        } elsif (! defined($rc)) {
            die("Failure reading config file '$file' - $!");
        } elsif (! $rc) {
            die("Failure processing config file '$file'");
        } else {
        	#print STDERR "Loaded config file '$file'\n";
        }
    }
}
sub get_config {
	my $namespace = shift;
	return $cfg::{$namespace} if defined($cfg::{$namespace});
	warn("Config namespace $namespace not found.\n");
}
sub clear_config {
	my $namespace = shift;
	$cfg::{$namespace} = undef;
}

#our @log;
#sub log_add {
#	my ($input)  = @_;
#	push(@log,strftime("%Y-%m-%d %H:%M:%S : ", localtime()). $input);
#}
#sub log_last {
#	my ( $lines ) = shift || 20;
#	return ($lines >= @log) ? @log : @log[-$lines..-1];
#}
#sub log_prune {
#	my ( $lines ) = shift || 20;
#	return @log = log_last($lines);
#}

1;