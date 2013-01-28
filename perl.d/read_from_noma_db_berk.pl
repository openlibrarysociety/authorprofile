#!/usr/bin/perl

use BerkeleyDB;

tie %acis_db_h, "BerkeleyDB::Hash",
  -Filename => '/home/aupro/ap/var/noma.db'
  or die "Cannot open file $filename: $! $BerkeleyDB::Error\n" ;

map {print $_."\n"} (keys %acis_db_h)

