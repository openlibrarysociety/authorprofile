#!/usr/bin/perl

use strict;
use warnings;

use lib qw( /home/aupro/ap/perl/lib /home/aupro/usr/lib/perl );

use AuthorProfile::Vertical;

use Data::Dumper;

sub sort_authors {

  my @authors=@{$_[0]};
  my $in_authors=shift;
  my $field=shift;
  my $sort_order=shift;

  my $condition=shift;
  my $cond1=shift;
  my $cond2=shift;

  my @records;

  #if(not scalar @authors) {
  die 'Fatal: Empty array passed to sort_authors' if not scalar @authors;
    #warn "Empty \$in_authors in sort_authors" if $VERBOSE;
    #return $in_authors;
  #}

  my @results;
  foreach my $author (@authors) {
    print "Looking for $author in authorprofile.noma...\n" if $VERBOSE;
    @results=AuthorProfile::Common::get_from_mongodb($COLL,{'author' => $author});

    my $record=pop @results;
    
    if(not $record) {
      warn "Could not retrieve record for $author in sort_authors" if $VERBOSE;
      next;
      # die "Fatal Error: Could not retrieve record for $author in sort_authors";
    }
    push @records,$record;
  }

  my @sorted_records;

  if($condition) {
    foreach my $author_record (@records) {
      if(not ($author_record->{$cond1} or $author_record->{$cond2})) {
        warn 'Records not purged properly:';
        print Dumper @records;
        print Dumper $cond1;
        die Dumper $cond2;
      }
      # 'GT' flag
      if($condition eq 'GT') {
        if($author_record->{$cond1} > $author_record->{$cond2}) {
          push @sorted_records,$author_record->{'author'};
        }
      }
      else {
        die 'Fatal Error: Bad condition value passed to sort_authors';
      }
    }
  }

  if($sort_order) {
    # Ascending (alternative sorting scheme)
    @sorted_records=(sort {$a->{$field} <=> $b->{$field}} @records);
  }
  else {
    # Descending (default sorting scheme)
    @sorted_records=(sort {$b->{$field} <=> $a->{$field}} @records);
  }
  if(not @sorted_records) {
    warn "Fatal Error: Failed to sort records";
    die Dumper @records;
  }

  my @sorted_authors;
  foreach (@sorted_records) {push @sorted_authors,$_->{'author'}}

  return \@sorted_authors;
}

1;
