#!/usr/bin/perl

use strict;
use warnings;

# Common to all AuthorProfile scripts
use lib qw( /home/jrgriffiniii/perl.d/authorprofile/lib/ );
use AuthorProfile::Conf;

# Imported from another script
# Originally authored by Thomas - modified by James

## write XML document
sub work_with_doc {
  my $doc=shift;
  my $author_sids=shift;
  my $data_element=$doc->documentElement;

  ## the sid of the author is always last
  my $sid_element= pop @{$data_element->getElementsByTagNameNS($acis_ns, 'shortid')};
  my $sid=$sid_element->textContent;

  ## is this an author?
  my $accepted_element = pop @{$data_element->getElementsByTagName('isauthorof')};

  # This checks to ensure that no one author with no claimed documents has their SID passed to the $author_sids structure.
  # Unless I am mistaken, this is what function the $empty_array statements serve.
  if(not $accepted_element) {
    return undef;
  }

  # ???
  # There are AMF elements with the tag name 'empty-array'?
  my $emptyarray_element = pop @{$accepted_element->getElementsByTagName('empty-array')};
  if($emptyarray_element) {

    return undef;
  }
  push(@$author_sids, $sid);
  return 1;
}

1;
