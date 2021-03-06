package AnyEvent::Web::Util;

BEGIN { AnyEvent::common_sense }

use Encode;
use base 'Exporter';

our @EXPORT = qw(
  	time2str print_unicode 
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

sub print_unicode {
    sprintf "%04x", ord Encode::decode("UTF-8", shift);
}
1;