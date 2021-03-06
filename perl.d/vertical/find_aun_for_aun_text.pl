#!/usr/bin/perl

use strict;
use warnings;

use lib qw( /home/aupro/ap/perl/lib /home/aupro/usr/lib/perl );

use AuthorProfile::Common qw( add_status );
use AuthorProfile::Vertical;

sub find_aun_for_aun_text {

  my $aunexesForAuversionRecord;

  # Global structure

  # This processes one auverted record per invocation.
  my $root_element=shift;

  my $auma=shift;

  print "Parsing auversion record...\n" if $VERBOSE;

  $root_element=&AuthorProfile::Common::add_status($root_element, $auma); 

  my @text_elems;
  eval { @text_elems=$root_element->getChildrenByTagName('text'); };
  if($@) {
    if ($VERBOSE > 0) { print("Auverted record bears no accepted texts.\n"); }
    next;
  }

  my $parsed_texts;
  
  my @hasauthor;
  my $text;
  

  
  my $status;
  my $name;
  my $k;
  my $collab_str;

  my $init_aun=undef;
  my $collaborators=undef;
  my $total_neighbors=undef;

  foreach my $text_elem (@text_elems) {
    $text=$text_elem->getAttribute('id');
    if ($VERBOSE > 0) { print("Processing $text...\n"); }
    if(defined($parsed_texts->{$text})) {
    }
    $k=&get_text_total_auth($text_elem);
    if($k <= 0) {
      warn("WARNING: Could not find the total amount of authors for $text.\n");
      die;
      next;
    }
    if($k == 1) {
      print "$text only has one author, skipping $text...\n" if $VERBOSE;
      next;
    }
    # Find the collaboration strength by which to increment (the inverse value of) a single edge's weight for this <text/>. 
    $collab_str=1/($k - 1);

    
    foreach my $name_elem ($text_elem->getChildrenByTagName('hasauthor')) {
      $name_elem=$name_elem->getChildrenByTagName('person')->[0]->getChildrenByTagName('name')->[0];
      $status=$name_elem->getAttribute('status');
      if($status == 0) {
        my $aunex=$name_elem->textContent();
        # The primary aunex, in this case, is merely the aunex specified in the auverted record being parsed.
        $aunex=&decode_utf8($aunex);
        $aunex=normalize_name($aunex);

        # From here, obtain all of the neighbors

        # if ($VERBOSE > 0) { print("Found aunex $aunex.\n"); }

        $collaborators=&find_aunexes_for_aun($aunex);
        if($collaborators eq 'error') { next; }

        foreach my $collaborator (keys %{$collaborators->{'w'}}) {
          if(not defined ($aunexesForAuversionRecord->{'w'}->{$aunex}->{$collaborator})) {
            if ($VERBOSE > 0) { print("Found primary aunex $collaborator for initial aunex $aunex.\n"); }
            $aunexesForAuversionRecord->{'w'}->{$aunex}->{$collaborator}=$collaborators->{'w'}->{$collaborator};
          }
        }
      }
    }
  }
  my $txttot=$#text_elems + 1;
  if ($VERBOSE > 0) { print("Found a total of $txttot texts specified for the auverted record.\n"); }

  # $aunexesForAuversionRecord->{'w'}->{$aun_1}->{$aun_2}
  
  # Calculate the symmetric weighted edges between authors and primary aunexes by finding the inverse value of the summation of the collaboration strengths obtained for every <text/> collaborated upon by both author $owner_id and aunex $name.
  foreach my $i (keys %{$aunexesForAuversionRecord->{'w'}}) {
    foreach my $j (keys %{$aunexesForAuversionRecord->{'w'}->{$i}}) {
      $aunexesForAuversionRecord->{'w'}->{$i}->{$j}=1/($aunexesForAuversionRecord->{'w'}->{$i}->{$j});
    }
  }
  
#  if($STORE_EDGES) { mp_store($aunexesForAuversionRecord, $EDGES_FILE_PATH); } 
  if($STORE_EDGES) { AuthorProfile::Common::json_store($aunexesForAuversionRecord, $EDGES_FILE_PATH); } 

  return $aunexesForAuversionRecord;
}

1;
