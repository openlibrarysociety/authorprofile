#!/usr/bin/perl

use strict;
use warnings;

use XML::LibXML;

sub get_text_total_auth {
  my $text_elem=shift;
  my $collab_str=0;
  # die $text_elem->firstChild->toString;
  foreach my $name_elem ($text_elem->getChildrenByTagName('hasauthor')) {
    # print Dumper $name_elem;
    $collab_str++;
  }
  return $collab_str;
}

1;
