#!/usr/bin/perl

use strict;
use warnings;

use lib qw( /home/aupro/ap/perl/lib /home/aupro/usr/lib/perl );
use BerkeleyDB;

use AuthorProfile::Vertical;

sub create_vema_db {

  my $vema_db_file=shift;

  # Construct the BerkDB ENV
  
  # Close the old database
  # $VEMA_DB->db_close;

  # Close the old database environment
#  $g_vema_db_env->close;

#  $g_vema_db_env = new BerkeleyDB::Env
#    -Home   => $vema_db_dir,
#      -Flags  => DB_CREATE| DB_INIT_CDB | DB_INIT_MPOOL
#        or die "cannot open database: $BerkeleyDB::Error\n";
  
  # Construct the handler-object for the BerkDB that stores the $vema values
  my $vema_db = new BerkeleyDB::Hash
    -Filename => $vema_db_file,
      -Flags    => DB_CREATE
        or die "cannot open database: $BerkeleyDB::Error\n";

  return $vema_db;
}

1;
