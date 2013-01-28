#!/usr/bin/perl

use strict;
use warnings;

use lib qw( /home/aupro/ap/perl/lib /home/aupro/usr/lib/perl );

use AuthorProfile::Vertical;
# Included for:
# $COLL
# @AUTHORS
# $VERBOSE


sub get_authors_missing_field {

  my @authorIDs=@{$_[0]};
  # my $author_sids=shift;

  #if(not scalar $author_sids) {
  die 'Fatal: Empty array passed to get_authors_missing_fields' if not scalar @authorIDs;

  #my $author_sids;
  #die 'Fatal: Empty array passed to get_authors_missing_fields' if not scalar @{$author_sids};
  #  return $author_sids;
  #}

  my $field=shift;
  my $id_field=shift;
  my $sort=shift;
  my $sort_field=shift;
  my $sort_order=shift;

  my @sortedAuthors;

  my $counter=0;
  my @filtered_authors;

  foreach my $author (@authorIDs) {
  # foreach my $author (@{$author_sids}) {

    my @results=AuthorProfile::Common::get_from_mongodb($COLL,{'author' => $author});
    my $record=pop @results;

    if(not $record) {
      warn "Warning: Could not retrieve the record for $author";
      next;
    }

    if(not $record->{$field}) {
      push @filtered_authors,$author;
      splice @authorIDs,$counter,1;
      # splice @{$author_sids},$counter,1;
      print "The vema record for $author is missing the field $field\n" if $VERBOSE > 0;
    }
    $counter++;
  }

  if($sort) {
    if(not scalar @filtered_authors) {
      warn "Could find no authors missing a value for $field";
      return;
      # return $author_sids;
    }

    my $sorted_filtered_authors=sort_authors(\@filtered_authors,$sort_field,$sort_order);

    # if(not scalar @{$sorted_filtered_authors}) {
    die 'Fatal: sorted_authors failed in get_authors_missing_field' if not scalar @{$sorted_filtered_authors};
      #return $author_sids;
    #}

    #else {
    foreach (@{$sorted_filtered_authors}) {push @sortedAuthors,$_}
    return @sortedAuthors;
    #}
  }

  foreach (@filtered_authors) {push @sortedAuthors,$_}
  return @sortedAuthors;
}

1;
