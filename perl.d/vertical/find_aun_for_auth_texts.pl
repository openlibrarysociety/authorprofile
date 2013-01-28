#!/usr/bin/perl

use strict;
use warnings;

use lib qw( /home/aupro/ap/perl/lib /home/aupro/usr/lib/perl );
use utf8;
use XML::LibXML;
binmode(STDOUT,"utf8");

use AuthorProfile::Conf;
use AuthorProfile::Common qw( add_status );
use AuthorProfile::Vertical;



# 01/14/11 - James

  # This relates aunexes to author sID's that are only 1 binary step away from an author.
  # $aun_auth_papers->{always author}->{always aunex}
# This draws solely upon the data available in the ACIS author records (currently located in ~/opt/amf/3lib/am) in $acis_dir.

sub find_aun_for_auth_texts {

  my $aunexesForACISRecord;

  # Global structure
  my $auma=shift;
#  my $auth_file=shift;

  my $input_files=shift;

  my @files;
  $files[0]=$input_files;

# The edges are to be calculated for each record as each record is processed.

  foreach my $file (@files) {
    chomp $file;

    print "Processing $file...\n" if $VERBOSE;

#    if ($VERBOSE > 0) { print("Processing $file...\n"); }

    my $root_element=&AuthorProfile::Common::add_status(AuthorProfile::Common::get_root_from_file($file),$auma); 
    if(not $root_element) {
      warn "WARNING: Could not parse $file.\n";
      next;
    }

    # Note: The first <person> is taken to be the author for which this record was generated.
    my $owner_id=$root_element->getChildrenByTagName('person')->[0]->getChildrenByTagNameNS($acis_ns, 'shortid')->[0]->textContent();

    my @texts_elems;
    eval { @texts_elems=$root_element->getChildrenByTagName('person')->[0]->getChildrenByTagName('isauthorof'); };
    if($@) {
      warn "WARNING: $file contains no records for texts accepted by the author.\n" if $VERBOSE;
      next;
    }


    my $parsed_texts;
    my @hasauthor;
    my $status;
    my $name;
    my $k;
    foreach my $texts_elem (@texts_elems) {

      my $text_elem=$texts_elem->getChildrenByTagName('text')->[0];
      my $text=$text_elem->getAttribute('ref');
      print "Parsing $text node...\n" if $VERBOSE;
      if(defined($parsed_texts->{$text})) {
        print "$text has already been parsed.\n" if $VERBOSE;
        next;
      }

      # Find the total amount of authors for this <text/>.
      $k=&get_text_total_auth($text_elem);
      if($k <= 0) {
        warn "WARNING: Could not find the total amount of authors specified in record $text" if $VERBOSE;
        next;
      }
      if($k == 1) {
        print "Record $text only has one author specified, skipping the record...\n" if $VERBOSE;
        next;
      }

      # Find the collaboration strength by which to increment (the inverse value of) a single edge's weight for this <text/>. 
      my $collab_str=1/($k - 1);

      foreach my $name_elem ($text_elem->getChildrenByTagName('hasauthor')) {

        $name_elem=$name_elem->getChildrenByTagName('person')->[0]->getChildrenByTagName('name')->[0];
        $status=$name_elem->getAttribute('status');
        if($status == 0) {

          my $aunex=$name_elem->textContent();
          $aunex=&decode_utf8($aunex);

          # Note: Just for output
          if(not defined ($aunexesForACISRecord->{'w'}->{$owner_id}->{$aunex})) {
            print "Found aunex $aunex for author $owner_id in record $text" if $VERBOSE;
          }

          $aunexesForACISRecord->{'w'}->{$owner_id}->{$aunex}+=$collab_str;
        }
      }

      my $numTextsForAuthor=$#texts_elems + 1;
      print "Found a total of $numTextsForAuthor records for the author $owner_id.\n" if $VERBOSE;
    }
  }

  # Calculate the symmetric weighted edges between authors and primary aunexes by finding the inverse value of the summation of the collaboration strengths obtained for every <text/> collaborated upon by both author $owner_id and aunex $name.
  foreach my $i (keys %{$aunexesForACISRecord->{'w'}}) {
    foreach my $j (keys %{$aunexesForACISRecord->{'w'}->{$i}}) {
      $aunexesForACISRecord->{'w'}->{$i}->{$j}=1/($aunexesForACISRecord->{'w'}->{$i}->{$j});
    }
  }
  
#  if($STORE_EDGES) { mp_store($aunexesForACISRecord, $edges_tmp_pack_file); } 
  if($STORE_EDGES) { AuthorProfile::Common::json_store($aunexesForACISRecord, $EDGES_FILE_PATH); } 
  
  return $aunexesForACISRecord;
}

1;
