#!/usr/bin/perl -w                                         # -*- perl -*-

use strict;
use lib qw( ./lib );
use ExtUtils::MakeMaker;
$|++;

WriteMakefile(
	      NAME              => 'Lingua::EN::NamedEntity',
	      VERSION_FROM      => 'NamedEntity.pm', # finds $VERSION
	      PREREQ_PM         => { DB_File => 0,
				     'Lingua::Stem::En' => 0,
				     'Compress::Zlib' => 0,
				     'LWP::Simple' => 0
				   },
	      ($] >= 5.005 ?
	       (ABSTRACT_FROM  => 'NamedEntity.pm',
		AUTHOR         => 'Simon Cozens') : ()),
	     );



package MY;

sub postamble {
      return <<"EOF";
database:
\tperl ./data/mkdb.pl

EOF
}

sub test {
    my $class = shift;
    my $makefragment = $class->SUPER::test(@_);
    $makefragment =~ s/^(test ::)/$1 database/m;
    return $makefragment;
}

sub install {
    my $class = shift;
    my $makefragment = $class->SUPER::install(@_);
    $makefragment =~ s/^(install ::)/$1 database/m;
    return $makefragment;
}


