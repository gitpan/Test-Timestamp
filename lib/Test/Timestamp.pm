package Test::Timestamp;

use strict;
use Time::HiRes;

use vars qw($VERSION $FORMAT $FORMAT_A $NUMBER $T_CALLER $T_LABEL $OVERHEAD_N $OVERHEAD_ITER);
($VERSION) = ('$Revision: 1.2 $' =~ /([\d\.]+)/);
$FORMAT =   "%19.6f: %12.6f: %s\n";			# timestamp, increment, label
$FORMAT_A = "%19.6f:             : %s\n";	# timestamp, label
$NUMBER = 1;			# a package global serial number
$OVERHEAD_N = 100;		# when deriving the method call overhead, make this many method calls...
$OVERHEAD_ITER = 5;		# and repeat the whole lot this many times

sub new {
	my $class = shift;
	my %opts = @_;

	my $now = Time::HiRes::time();
	my $self = [
		{
			'name' => ($opts{'name'} || $NUMBER++),
			'uncorrected' => ($opts{'uncorrected'} || 0),
			'quietDestroy' => ($opts{'quietDestroy'} || 0),
		},
		$now,
		$now,
	];
	bless $self, $class;
	return $self;
}

# $self is an array reference.
# Slot 0 is a metadata hashref, e.g. name of this stamper object
# Slot 1 is the creation time
# Slot 2 is when the object was initialized
# all subsequest slots are timestamps - arrayrefs like [ time, label ]

sub init {
	my $self = shift;
	$#$self = 1;
	$self->[2] = Time::HiRes::time();
}

sub stamp {
	my $label = ($_[1] || sprintf("File: %s Line: %s", (caller())[1,2]));
	push @{$_[0]}, [Time::HiRes::time(), $label];
}

sub division {	# in the high school halls...
	push @{$_[0]}, '-';
}

sub banner {
	push @{$_[0]}, 'H'.$_[1];
}

sub display {
	my $self = shift;
	print STDERR $self->resultAsString;
}

sub resultAsString {
	my $self = shift;
	my ($data, $created, $inited, @stamps) = @$self;
	my ($t_caller, $t_label);
	
	my $str = '';

	$str .= "#\n# Test::Timestamp Results for: $data->{'name'}\n";

	# timing corrections
	if ($data->{'uncorrected'}) {
		($t_caller, $t_label) = (0, 0);
		$str .= "# No attempt to correct for calling overhead\n";
	} else {
		($t_caller, $t_label) = _findOverheads();
		$str .= "# Attempting to correct for calling overhead - stamp(): $t_caller stamp(LABEL): $t_label\n";
		$str .= "# Figures in 'Time' and 'Increment' columns have been corrected\n";
	}
	
	$str .= "#              Time:    Increment: Label\n";
	$str .= sprintf $FORMAT_A, $created, 'Created';
	$str .= sprintf $FORMAT, $inited, 0, 'Inited';
		
	my $last = 0;
	foreach (@stamps) {
		if (! ref) {
			if ($_ eq '-') {
				$str .= ('# ' . ('-' x 76) . "\n");
			} elsif (m/^H(.*)$/) {
				$str .= "# ----- $1\n";
			}
			next;
		}
		my $label = $_->[1];
		# to correct for method call overhead we simply add the appropriate amount to
		# $inited, which ensures that any subsequent comparisons to it allow for all
		# previous calls.
		if ($label =~ m/^File: .* Line: \d*$/) {
			$inited += $t_caller;
		} else {
			$inited += $t_label;
		}

		my $now = $_->[0]-$inited;
		my $inc = 0;
		$inc = $now - $last;
		$str .= sprintf $FORMAT, $now, $inc, $label;
		$last = $now;
	}
	$str .= "# End of Timestamp data for: $data->{'name'}\n#\n";
	return $str;
}

sub DESTROY {
	unless ($_[0]->[0]->{'quietDestroy'}) {
		$_[0]->display;
	}
}

### PRIVATE ROUTINES

# returns the average overhead for a non-labelled and labelled call to stamp()
sub _findOverheads {
	# derive figures if we haven't got them already
	unless (defined $T_CALLER && defined $T_LABEL) {
		_runOverheadCheck();
	}
	return ($T_CALLER, $T_LABEL);
}

# actually benchmarks the calls, so that we can update the values if needed
sub _runOverheadCheck {
	my $test = new Test::Timestamp;
	my ($t_caller, $t_label);
	
	# run the test several times to interleave tests and hopefully be more accurate
	for (1..$OVERHEAD_ITER) {
		# how long does the non-labelled calls take
		my $start = Time::HiRes::time();
		for (1 .. $OVERHEAD_N) { $test->stamp; }
		$t_caller += (Time::HiRes::time() - $start);
		
		# how long do the labelled calls take
		$start = Time::HiRes::time();
		for (1 .. $OVERHEAD_N) { $test->stamp('t'); }
		$t_label += (Time::HiRes::time() - $start);
	}
	$t_caller /= ($OVERHEAD_N * $OVERHEAD_ITER);
	$t_label /= ($OVERHEAD_N * $OVERHEAD_ITER);
	
	# re-bless so that our DESTROY is not called
	bless $test, 'UNIVERSAL';
	($T_CALLER, $T_LABEL) = ($t_caller, $t_label);
}

1;

__END__

=pod

=head1 NAME

Test::Timestamp - Create timestamp objects for testing or profiling

=head1 SYNOPSIS

	use Test::Timestamp;
	my $record = new Test::Timestamp;
	# or give it a name, to distinguish it...
	my $record_named = new Test::Timestamp(name => 'parse_xml() timer');

	$record->init;      # optionally initialize the object if you've used it before
	$record->stamp;     # insert a timestamp
	# do something here...
	$record->division;  # put a horizontal rule in the output
	$record->stamp('after difficult loop');  # record another stamp

	# you can now output the timestamp record yourself...
	$record->display;
	# ...or wait until the object is destroyed
	# when the display will happen automatically

=head1 DESCRIPTION

With this module you can create one or more timestamp objects which can be used
to record the exact time when a certain point in your code was executed.
The Devel::DProf module and its relatives all time subroutine calls, which is usually
a good enough resolution for profiling your code and finding slow parts, but
sometimes you need to examine a routine in finer detail - hence the idea of timestamps.
This routine uses Time::HiRes

Objects can be given a name in the constructor, in case you want to distinguish
many different timers. Objects may be re-used by calling the init() method to reset them.

The main method is 'stamp' which adds a timestamp to the object. You can supply a
label for the timestamp, so that you know what point in the code it relates to, but
if you don't then the default is to use the filename and line number at which it
was called.

There are various ways to display the timestamp data: call the 'display' method explicitly, 
wait until the object is destroyed when the display method will be called automagically
(unless the object was created with quietDestroy set to true), or call resultAsString()
to get the results string.
Use whichever method is appropriate.

=head1 METHODS

=over 4

=item new Test::Timestamp( [ OPTIONS ] )

Create a new object and initialize it. You may also supply options to the constructor,
if you want. Supply them in the form C<option =E<gt> "value">. See the 'OPTIONS' section.

=item init

Reinitializes the object, and clears out all stored timestamps.

=item stamp( [ LABEL ] )

Add another timestamp to the object with a useful label. You may supply a label yourself,
or the default is to use the filename and line number at which the timestamp was called.

=item division

Inserts a horizontal line in the output data. Especially useful to demarcate major sections in the output
(e.g. the start of a loop) or if the object is used many times (e.g. as a package global under mod_perl)

=item banner( TEXT )

Inserts a banner in the output data containing the given text. Useful if you want to mark execution points
but not timestamp them, or to record metadata in the output. E.g. under a webserver all the output
will go to one logfile and you may want to know which process the timestamps refer to and what the CGI
parameters were.

=item display

Prints the current timestamp data to STDERR. See below for an example.

=item resultAsString

Returns a string containing the output data that display() would print to standard error - internally
display() calls this method.

=back

=head1 OPTIONS

These are the options recognized in the constructor:

=over 4

=item name =E<gt> 'A String'

Allows you to give a useful name to the object - otherwise it's just given a unique serial number.

=item uncorrected =E<gt> 0

Turns off any attempt to correct for method call
overhead. Default is 0 - i.e. we do try to correct for the overhead. Set to 1 or 0.

=item quietDestroy =E<gt> 0

Inhibits display() being called when the object is destroyed. Default is 0 - i.e. display() is
called. Set to 1 or 0.

=back

=head1 EXAMPLE OUTPUT

	#
	# Test::Timestamp Results for: Example 1
	# Attempting to correct for calling overhead - stamp(): 0.00112497138977051 stamp(LABEL): 0.000495590209960937
	# Figures in 'Time' and 'Increment' columns have been corrected
	#              Time:    Increment: Label
	  3102871000.597497:             : Created
	  3102871000.597497:     0.000000: Inited
			   0.001612:     0.001612: File: Programs:01base.t Line: 21
			   0.003472:     0.001860: Before require
	# ----------------------------------------------------------------------------
			   1.006649:     1.003177: File: Programs:01base.t Line: 35
			   1.722408:     0.715759: XML parse
	# ----- A banner
			   1.722417:     0.000010: end
	# End of Timestamp data for: Example 1
	#

The ouput contains a header, body and footer. The header tells you which timestamp object
this is. The footer also tells you which object this is, to allow easy automated extraction of 
timestamp data. All times are in seconds. If the times are being corrected for the added time
of calling 'stamp()' then a line appears saying what values have been worked out for these
corrections.

The body always has entries for 'Created' and 'Inited', which are the absolute times
at which the object was created, and when it was last initialized. The body then has 0 or more
entries for every timestamp. The first column is the time relative to when the object was
initialized. The second column is the time between this timestamp and the last one. The third
column is the label for the stamp.

=head1 CAVEATS

This module uses Time::HiRes for its timing, so the resolution ultimately depends on the
high-resolution time functions that Time::HiRes uses on your system.

All output is deferred until DESTROY() or display() is called - this is simply to reduce
the overhead in calling stamp() to the bare minimum.
Like all method and subroutine calls there is an inherent overhead in calling the stamp()
method and the use of this module will slightly slow down your program.

When displaying the results, this module attempts to correct for the calling overhead.
If you would rather do the corrections yourself see the 'uncorrected' option in the constructor.
The resultAsString() routine, and hence display(), need to do a fair bit of work so it's 
probably best to call them well away from the code you're measuring (hence the default
behaviour of displaying only on DESTROY). On the other hand, stamp(), division() and banner()
are as lightweight as possible.

None of the text you supply for labels, banners etc. is sanitized or checked, so avoid using
high-order characters or control characters.

If you need to optimize pieces of code that are quite short perhaps the Benchmark module would be
a better place to start. If you only need to examine your code at the subroutine level then the
Devel::DProf module should be sufficient. If you need to examine your code at a higher resolution
then this is a good tool.

=head1 PREREQUISITES

Time::HiRes

=head1 VERSION

$Id: Timestamp.pm,v 1.2 2002/04/28 22:08:53 piers Exp $

=cut
