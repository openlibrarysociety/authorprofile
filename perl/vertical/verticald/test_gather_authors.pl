#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use XML::LibXML;

# Common to all AuthorProfile scripts
use lib qw( /home/aupro/ap/perl/lib/ );
use AuthorProfile::Conf;

my $VERTICALD_PATH="$ENV{'HOME'}/ap/perl/bin/vertical/verticald";
require "$VERTICALD_PATH/gather_authors_from_profile_dir.pl";

print Dumper gather_authors_from_profile_dir('/home/aupro/ap/amf/3lib/am');
