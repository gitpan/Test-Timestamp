use ExtUtils::MakeMaker;

# $Id: Makefile.PL,v 1.1 2002/04/28 22:04:32 piers Exp $

WriteMakefile(
	AUTHOR		=> 'P Kent (pause@selsyn.co.uk)',
	ABSTRACT	=> 'Put timestamps in your code to see how long parts take',
	NAME		=> 'Test-Timestamp',
	dist		=> {
		COMPRESS	=> 'gzip',
		SUFFIX		=> '.gz',
	},
	VERSION_FROM	=> 'lib/Test/Timestamp.pm',
	PREREQ_PM	=> { 'Time::HiRes' => 0 },
	INC		=> '',
);

