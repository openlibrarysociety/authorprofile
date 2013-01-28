#!/usr/bin/perl

use strict;
use warnings;

use lib qw( /home/aupro/ap/perl/lib /home/aupro/usr/lib/perl );
use BerkeleyDB;

use AuthorProfile::Vertical;

sub create_noma_db {

  my $noma_db_file=shift;

  

  # Construct the BerkDB ENV
  
  # Close the old database
  # $g_noma_db->db_close;

  # Close the old database environment
#  $g_vema_db_env->close;

#  print $vema_db_file;

  #ENV DISABLED
#  my $vema_db_dir=$vema_db_file;

#  $vema_db_dir=~s|^\.\.||;
#  $vema_db_dir=~s|^\.||;
#  $vema_db_dir=~s|[a-zA-Z0-9\.]*$||;
#  $vema_db_dir=~s|/$||;

#  $vema_db_file=~s|^$vema_db_dir||;

#  $g_vema_db_env = new BerkeleyDB::Env
#    -Home   => $vema_db_dir,
#      -Flags  => DB_CREATE| DB_INIT_CDB | DB_INIT_MPOOL
#        or die "cannot open database: $BerkeleyDB::Error\n";
  
  # Construct the handler-object for the BerkDB that stores the $vema values
  my $noma_db = new BerkeleyDB::Hash
    -Filename => $NOMA_DB_FILE,
      -Flags    => DB_CREATE
        #        -Env      => $g_vema_db_env
          or die "cannot open database: $BerkeleyDB::Error\n";

  return $noma_db;
}

1;
