#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use XML::LibXML;

# Common to all AuthorProfile scripts
use lib qw( /home/aupro/ap/perl/lib/ );
use AuthorProfile::Conf;
use AuthorProfile::Common qw (get_from_mongodb get_mongodb_collection);

my $VERTICALD_PATH="$ENV{'HOME'}/ap/perl/bin/vertical/verticald";
require "$VERTICALD_PATH/gather_authors_from_profile_dir.pl";
require "$VERTICALD_PATH/get_authors_missing_field.pl";



my $FIELD='began_calculation';
my $FIELD='began_calculation';

foreach (gather_authors_from_profile_dir('/home/aupro/ap/amf/3lib/am')) {
  print $_,"\n";
  
  my @results=AuthorProfile::Common::get_from_mongodb(AuthorProfile::Common::get_mongodb_collection('noma','authorprofile'),{'author' => $_});
  my $record=pop @results;

  if(not $record) {
    warn "Warning: Could not retrieve the record for author";
    next;
  }

  if(not $record->{'began_calculation'}) {
    print 'missing began calc';
  }
  
  if(not $record->{'ended_calculation'}) {
    print 'missing ended calc';
  }
}

