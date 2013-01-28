#!/usr/bin/perl

use strict;
use warnings;

use lib qw( /home/aupro/ap/perl/lib /home/aupro/usr/lib/perl );

use AuthorProfile::Vertical;
use AuthorProfile::Common qw(json_retrieve put_in_mongodb);

use Data::Dumper;

sub populate_noma_mongodb {

  my $acis_values;
  $acis_values=AuthorProfile::Common::json_retrieve($LAST_CHANGE_PATH);

  die Dumper $acis_values;

  my $results;

  for my $acis_author (keys %{$acis_values}) {

    $results=AuthorProfile::Common::put_in_mongodb($COLL,{'last_change_date' => $acis_values->{$acis_author}},'author',$acis_author);
  }

  print 'authorprofile.noma successfully populated with authors from the ACIS system' if $VERBOSE;
  return 0;
}

populate_noma_mongodb;

1;
