#!/usr/local/bin/perl -w
use strict;
use Test;
use lib qw(../lib ./lib ::lib :lib);
use Test::Timestamp;
# $Id: 01base.t,v 1.1 2002/04/28 22:04:37 piers Exp $
plan tests => 17;

{
	my ($x, $y) = Test::Timestamp::_findOverheads();
	ok( $x > 0 );
	ok( $y > 0 );
	
}

my $record = new Test::Timestamp(
	name => 'Example 1',
	uncorrected => 0,
	quietDestroy => 1,
);

my $x;
for (1..200) {
	$x .= sprintf $_;
}
###### THIS FILE IS SENSITIVE TO LINE NUMBERS
$record->stamp;

for (1..200) {
	$x .= sprintf $_;
}

$record->stamp('foobar');

for (1..200) {
	$x .= sprintf $_;
}

sleep 1;
$record->stamp();
sleep 1;
$record->division;
$record->stamp();
$record->banner("A banner");
$record->stamp('end');
my $r = $record->resultAsString;

# print $r;

ok(scalar($r =~ /# Attempting to correct/));
ok(scalar($r =~ /: Created/));
ok(scalar($r =~ /: Inited/));
ok(scalar($r =~ /File: .* Line: 27/));
ok(scalar($r =~ /: foobar/));
ok(scalar($r =~ /# ---------------------------/));
ok(scalar($r =~ /# End of Timestamp data for: Example 1/));
ok(scalar($r =~ /# ----- A banner/));

{
	open(STDERR, '>TEMPFILE') or die("Can't open scratch file $!");
	my $record_2 = new Test::Timestamp(
		name => 'Example 2',
		uncorrected => 0,
		quietDestroy => 0,
	);
	$record_2->banner('BANNER');
	$record_2->stamp('POINT 1');
	$record_2->division;
	$record_2->stamp('POINT 2');
}
ok( -f 'TEMPFILE' );
open (IN, '<TEMPFILE') or die("Can't read scratch file $!");
undef $/;
my $s = <IN>;
close IN;

ok(scalar($s =~ /: Created/));
ok(scalar($s =~ /: Inited/));
ok(scalar($s =~ /# End of Timestamp data for: Example 2/));
ok(scalar($s =~ /: POINT 1/));
ok(scalar($s =~ /: POINT 2/));
ok(scalar($s =~ /# ----- BANNER/));
