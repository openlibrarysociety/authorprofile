#!/usr/bin/perl

use strict;
use warnings;

use lib qw( /home/aupro/ap/perl/lib /home/aupro/usr/lib/perl );

use AuthorProfile::Vertical;
use AuthorProfile::Common qw(json_retrieve put_in_mongodb);

use Data::Dumper;
use BerkeleyDB;
use JSON::XS;

sub populate_noma_mongodb {

  my $acis_values;

  my $filename='/home/aupro/ap/var/noma.db';

  my %acis_db_h;

  tie %acis_db_h, "BerkeleyDB::Hash",
                -Filename => $filename
        or die "Cannot open file $filename: $! $BerkeleyDB::Error\n" ;

  my $results;

  # Update the noma, put this in the crontab
  foreach my $acis_author (keys %acis_db_h ) {

    $results=AuthorProfile::Common::put_in_mongodb($COLL,{'last_change_date' => %{decode_json $acis_db_h{$acis_author}}->{'last_change_date'}},'author',$acis_author);

  }

  print 'authorprofile.noma successfully populated with authors from the ACIS system' if $VERBOSE;
  return 0;
}

populate_noma_mongodb;

#1;
