#!/usr/bin/perl

use strict;
use warnings;

use lib qw( /home/aupro/ap/perl/lib /home/aupro/usr/lib/perl );

use AuthorProfile::Vertical;

sub get_authors_sorted_by_field {

  # The source list of authors
  my $in_authors=shift;

  if(not scalar $in_authors) {
    warn 'Warning: Empty $in_authors passed to get_authors_sorted_by_field';
    return $in_authors;
  }

  my $field=shift;
  my $id_field=shift;

  my $condition=shift;
  my $cond1=shift;
  my $cond2=shift;

  my $sort_order=shift;

  my $sorted_authors=sort_authors(\@{$in_authors},$field,$sort_order,$condition,$cond1,$cond2);

  my $counter=0;
  foreach my $sorted_author (@{$sorted_authors}) {
    push @AUTHORS,$sorted_author;
    splice @{$sorted_authors},$counter,1;
    $counter++;
  }

  return $in_authors;
}

1;
