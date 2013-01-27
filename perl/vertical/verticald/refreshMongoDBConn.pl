#!/usr/bin/perl/

use strict;
use warnings;

use lib qw( /home/aupro/ap/perl/lib /home/aupro/usr/lib/perl );
use AuthorProfile::Conf;
use AuthorProfile::Common qw(get_mongodb_collection);
use AuthorProfile::Vertical;

sub refreshMongoDBConn {
  eval { $COLL=AuthorProfile::Common::get_mongodb_collection('noma'); };
  if($@) {
    die "Fatal Error: Could not connect to authorprofile.noma: $!";
  }
  return 0;
}

1;
