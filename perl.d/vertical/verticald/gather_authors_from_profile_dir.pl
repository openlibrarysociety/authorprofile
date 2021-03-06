#!/usr/bin/perl

use strict;
use warnings;

# Common to all AuthorProfile scripts
use lib qw( /home/jrgriffiniii/perl.d/authorprofile/lib/ );
use AuthorProfile::Conf;

my $VERTICALD_PATH="$ENV{'HOME'}/ap/perl/bin/vertical/verticald";
require "$VERTICALD_PATH/work_with_doc.pl";

# Imported from another script
# Originally authored by Thomas - modified by James

sub gather_authors_from_profile_dir {
  my $profile_dir=shift;
  my @author_sids;
  foreach my $file (`find $profile_dir -type f -name '*.xml'`) {
    chomp $file;
    open my $fh, "$file";
    binmode $fh; # drop all PerlIO layers possibly created by a use open pragma
    my $doc = eval {XML::LibXML->load_xml(IO => $fh);};
    if(not $doc) {
      warn "could not parse $file";
      next;
    }
    &work_with_doc($doc,\@author_sids);
  }
  return @author_sids; 
}

1;
