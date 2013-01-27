#!/usr/bin/perl

## enforce strict pragma
use strict;
## warn about possible problem
use warnings;

use lib qw( /home/aupro/ap/perl/lib /home/aupro/usr/lib/perl );
use BerkeleyDB;
use Carp::Assert;
use Data::Dumper;
use Date::Format;
use Encode;
use File::Basename;
use File::Compare;
use File::Copy;
use File::Path qw( make_path );
use File::Slurp;
use File::Temp qw/ tempfile tempdir /;
use IO::File;
use List::Util qw(shuffle);
use Text::Levenshtein qw( distance );
use utf8;
use XML::LibXML;
use XML::LibXSLT;

binmode(STDOUT,"utf8");

use AuthorProfile::Auvert qw( authorname_to_filename normalize_name );
use AuthorProfile::Common qw( add_status
                              json_store
                              json_retrieve
                              put_in_mongodb
                              get_from_mongodb
                              get_from_db_json
                              get_root_from_file );
use AuthorProfile::Conf;
use AuthorProfile::Network qw( vema_db_retrieve
                               noma_db_retrieve
                               store_vema_values
                               update_noma_values
                               generate_poma
                               compare_nodes_using_poma );
use AuthorProfile::Vertical;

# While we move towards the object-oriented API...
my $VRT_INCLUDE_PATH='/home/aupro/perl';
require "$VRT_INCLUDE_PATH/vertical/header.pl";
require "$VRT_INCLUDE_PATH/vertical/get_text_total_auth.pl";
require "$VRT_INCLUDE_PATH/vertical/find_aun_for_auth_texts.pl";
require "$VRT_INCLUDE_PATH/vertical/find_aun_for_aun_text.pl";
#require 'proc_args.pl';
#require 'proc_input.pl';
require "$VRT_INCLUDE_PATH/vertical/create_vema_db.pl";
require "$VRT_INCLUDE_PATH/vertical/create_noma_db.pl";

# Ensure that only one instance of this script it run on the server.
#use Sys::RunAlone;

######################################

## namespace constants
#my $amf_ns="http://amf.openlib.org";
#my $acis_ns="http://acis.openlib.org";
#my $xml_ns="";
my $g_acis_root_attr_const='http://acis.openlib.org/2007/doclinks-relations';

######################################

# LibXML global handlers. 
my $dom=XML::LibXML->new();
my $xslt = XML::LibXSLT->new();
$dom->keep_blanks(0);
# 01/07/11 - James: To increase efficiency, just use one set of global handles.
my $doc=undef;
my $root_elem=undef; 
my $parser=XML::LibXML->new();

######################################

# Environmental variables

######################################

# Input directory and file paths
my $g_log_dir="$home_dir/var/log/vertical";

# Deprecated - From the BerkeleyDB implementation
my $g_vert_stat_file='';

sub is_file_empty {
  my $file=shift;

  my ($fh,$data);
  open $fh, "< $file" or warn $!;
  binmode $fh;
  read $fh,$data,scalar $fh;
  close $fh;
  if($data) { return 0; }
  else { return 1; }
}

# Deprecated - From the BerkeleyDB implementation
my $g_vema_db_file='';

#######################################

my $g_collec_vema=AuthorProfile::Common::get_mongodb_collection('vema');
if(not $g_collec_vema) {
  die "Fatal Error: Could not retrieve 'vema' collection handler to database 'authorprofile'";
}

my $g_collec_noma=AuthorProfile::Common::get_mongodb_collection('noma');
if(not $g_collec_noma) {
  die "Fatal Error: Could not retrieve 'noma' collection handler to database 'authorprofile'";
}

#######################################

# Global variables

# The maximum binary distance for the exploration of specific aunex.
# Note that the default value is 2.
my $g_maxd=2;

# 01/18/12
# Setting the a node maximum is pointless
# The purpose of this was to eliminate the problem of authors for which the network exploration requires simply too much time
# Hence, it's not a node maximum that should be set, but a time limit
my $g_max_nodes=100000000;
my $g_node_increment=1;
my $g_max_nodes_exceeded=0;

my $g_init_time=time;
my $g_time_limit=604800;
my $g_time_increment=1;
my $g_timeout=0;



my $g_statuses_found=undef;
my $g_aunexes=undef;
my $g_all_auth=0;
my $g_parsed_texts=undef;

my $g_input=undef;

my $g_parsing_dir=0;


my $g_width_p=0;


my $g_furthest_depth;

my $g_furthest_depth_explored=0;

#########################################

# The auma: A structure linking author name-strings to ACIS ID's
my $auma=undef;
my $auma_gen="$home_dir/ap/perl/bin/ap_top";
# Flag for forcing the regeneration of the auma.

sub init_auma {
  ## check if auma is old,
  if(not -f $auma_file or (-M $auma_file) > 1 or $REGEN_AUMA) {
    system($auma_gen) == 0 or die "Fatal: Could not regenerate the auma structure: $!";
  }
  print "loading auma\n" if $VERBOSE;
  $auma=AuthorProfile::Common::json_retrieve($auma_file) or die "Fatal: Could not retrieve the auma structure: $!";
}

#########################################

# The poma: A structure linking ACIS ID's to network metrics

my $poma=undef;
my $g_force_poma_regen=0;

if(not -f $poma_file) {
  generate_poma;
}

$poma=AuthorProfile::Common::json_retrieve($poma_file) or die "Fatal: Could not retrieve the poma structure $!";

#########################################

# The vema: A structure linking author-name strings to trees in the citation network

# $vema->{DEST}->{'d'} = distance to START node, in binary steps.
# $vema->{DEST}->{'p'} = a space separeted path of intermediate nodes
# $vema->{DEST}->{'e'} = START
# $vema->{DEST}->{'w'} = weight of the path
# DB's are values
# the keys are the identifiers of the target node
# they are NOT the identifiers of the source nodes!
# they, essentially, convert the source node to target nodes

my $vema=undef;

# Deprecated: From BerkeleyDB implementation
my $g_vema_db_file_path='';
my $g_vema_db = undef;

#########################################

# The noma: A structure linking ACIS ID's to vertical calculation data
# $noma->{[SID]}->{'last_change_date'}
# $noma->{[SID]}->{'began_calculation'}
# $noma->{[SID]}->{'ended_calculation'}
# $noma->{[SID]}->{'furthest_depth'}

# Deprecated: From BerkeleyDB implementation
my $g_noma_db_file='';
my $g_noma_log_dir=$g_log_dir;
my $g_noma_log_file='noma.log';
my $g_noma_db = undef;

#########################################

# 01/18/12:
# To do: This implementation was based upon the original vertical script authored on the server snefru
# It should be restructured or removed outright

# The global edges calculated for the aunexs of each author for each given ACIS record.
# What are these exactly?
# These are the edges in the neighborhood generated by collaboration between registered registered authors and "initial" aunexes.  These "initial" aunexes are those aunexes which are specified within the profiles generated for registered authors by AuthorClaim.
# In other words:
# AuthorClaim -> profiles for registered authors
# profiles for registered authors -> aunexes for unregistered authors
# aunexes for unregistered authors = "initial aunexes"
# These are referred to as "initial" aunexes because thes are the nodes from which the network exploration is begun.
# With the $store_papers flag set, the edges can be stored into a MessagePack file for convenient recalculations.
# This is useful for debugging.

my $edges=undef;

sub init_edges {
  if($STORE_EDGES == 1 and -f $EDGES_FILE_PATH) {
    $edges=AuthorProfile::Common::json_retrieve($EDGES_FILE_PATH);
  }
}



#########################

# The invocation of the main() function.
&main();

#########################

# 01/18/12
# To do: Unlikely that this will ever be used, as this script will be invoked for individual authors by the wrapper/daemon
# Should be removed

sub parse_dir {
  my $dir=$_[0];
  if(not defined($dir)) {
    return 1;
  }
  $g_parsing_dir=1;
  # To do: Recursion
  my @files=`find $dir -name '*.amf.xml'`;
  shuffle(@files);
  foreach my $file (@files) {
    chomp $file;
    if ($VERBOSE > 0) { print("Processing $file...\n"); }
    if($file eq ($files[$#files])) {
      $g_parsing_dir=0;
    }
    &parse_file($file);
  }
  return 0;
}

sub parse_file {

  my $file=$_[0];
  if(not defined($file)) {
    return 1;
  }

  chomp $file;
  if(-d $file) {
    &parse_dir($file);
    return 0;
  }
  $doc=$dom->parse_file($file);
  $root_elem=$doc->documentElement();



  my $person_elem=$root_elem->getElementsByTagName('person')->[0];
  my $sid_elem=$root_elem->getElementsByTagNameNS($acis_ns, 'shortid')->[0];
  my $sid=$sid_elem->textContent();  
  
  my $record_type=undef;
  
  print "\"Dry run\" mode enabled: No transactions with the vertical integration database will be performed.\n" if $DEBUG and $VERBOSE;
  
  my $begin_calc_time=time();
  
  # Store within the noma the time at which the calculation of the vertical integration was initiated.
  
  # $noma->{[SID]}->{'began_calculation'}
  # $noma->{[SID]}->{'ended_calculation'}
  # $noma->{[SID]}->{'furthest_depth'}
  
  # IMPOSE AN ADDITIONAL TERMINAL CONDITION:
  # Maximum number of authors reached from the start_author
  # Hash: constructed for every neighbor
  
  if(update_noma_values($sid,$g_collec_noma,'began_calculation',$begin_calc_time)) {
    die "Fatal Error: Could not update the noma values for $sid";
  }
  
  $record_type=0;
  
  # Verify that this is an ACIS profile
  foreach my $root_attr ($root_elem->attributes()) {
    $record_type=1 if $root_attr->getData() eq $g_acis_root_attr_const;
  }

  $record_type == 1 or die 'Fatal: ACIS profile appears to be an auversion record';

  # If it hasn't been cached, regenerate the edges structure for an author
  # The auma structure is needed as an argument for AuthorProfile::Common::add_status
  $edges=&find_aun_for_auth_texts($auma, $file) if not $edges;

  &generate_vema_for_author($edges, $poma);

  # Free memory
  $edges=undef;
  $root_elem=undef;
  $doc=undef;
  
  if(update_noma_values($sid,$g_collec_noma,'ended_calculation',time())) {
    die "Fatal Error: Could not update the noma values for $sid";
  }
  if(update_noma_values($sid,$g_collec_noma,'furthest_depth',$g_maxd)) {
    die "Fatal Error: Could not update the noma values for $sid";
  }
  
  print "Vertical integration data successfully generated for $file.\n" if $VERBOSE;
  return 0;
}

#####################################################

sub get_root_from_file_libxml {
  my $file=shift;
  my $dom=XML::LibXML->new();
  if(-f $file) { my $doc=$dom->parse_file($file); }
  else { return; }
  if(defined($doc)) { return $doc->documentElement(); }
  else { return; }
}

# 01/14/11 - James

  # This relates aunexes to author sID's that are only 1 binary step away from an author.
  # $aun_auth_papers->{always author}->{always aunex}
# This draws solely upon the data available in the ACIS author records (currently located in ~/opt/amf/3lib/am) in $acis_dir.





sub get_aunexes_from_auverted_record {

  my $root_element=shift;

  my $person_element=$root_element->getChildrenByTagName('person')->[0];

  $root_element=&AuthorProfile::Common::add_status($root_element, $auma); 

  if ($VERBOSE > 0) { print("Searching for the first aunex in the auverted record...\n"); }

  my @text_elems;
  eval { @text_elems=$root_element->getChildrenByTagName('text'); };
  if($@) {
    warn("Auverted record bears no accepted texts.\n");
    return undef;
  }
  
  my @hasauthor;
  my $text;
  my $status;
  my $name;

  # Given that the "auverted" /ap record files are being parsed more than once, this should be a global variable.

  my $k=0;
  my $collab_str;

  foreach my $text_elem (@text_elems) {
    $text=$text_elem->getAttribute('ref');
    if ($VERBOSE > 0) { print("Parsing text $text...\n"); }

    foreach my $name_elem ($text_elem->getChildrenByTagName('hasauthor')) {
      if(not defined($name_elem->getChildrenByTagName('person')->[0])) {
        if ($VERBOSE > 0) { print("<hasauthor/> element bears no <person/> element.\n"); }
        next;
      }
      if(not defined($name_elem->getChildrenByTagName('person')->[0]->getChildrenByTagName('name')->[0])) {
        if ($VERBOSE > 0) { print("<hasauthor/> element bears no <name/> element.\n"); }
        next;
      }
      $name_elem=$name_elem->getChildrenByTagName('person')->[0]->getChildrenByTagName('name')->[0];
      $status=$name_elem->getAttribute('status');
      if($status == 0) {
        $name=$name_elem->textContent();
        if(defined($name)) {
          $name=&decode_utf8($name);
          return $name;
        }
      }
      else { next; }
    }
  }
  warn("Auverted record did not contain any authors.\n");
  return undef;
}

sub find_aunexes_for_aun {

  my $aunex=shift;

  $aunex or die 'Fatal: Empty $aunex passed to find_aunexes_for_aun';

  $aunex=&decode_utf8($aunex);

  # $aunexes->{'a'}=@(neighboring aunexes)
  # $aunexes->{'w'}->{aunex}=weighted edge between initial aunex and neighboring aunex

  # In order to increase efficiency, there is both a global and local function for the aunexes.
  # This is the $aunexes structure local to this function:
  my $aunexes;

  # Here is where the global structure $aunexes provides its utility:

  # Global $aunexes structure:
  # $aunexes->{'a'}=@(every aunex for which the neighbors have already been found, and the edges stored)
  # $aunexes->{'w'}->{$aun1}->{$aun2}

#  print "find_aunexes_for_aun - before normalization: $aunex\n";
  my $norm_aun=&normalize_name($aunex);
#  print "after normalization: $norm_aun\n";
#  <STDIN>;
  my $aun_file=&authorname_to_filename($norm_aun);

  $aun_file="$auvert_dir/$aun_file";
  
  if(not defined($aun_file) or not -f $aun_file) {

    warn("WARNING: Could not retrieve file name for $aunex in find_aun_for_aun.\n");
    return 'error';
  }
  my $root_element;
  eval { $root_element=$parser->parse_file($aun_file)->documentElement(); };
  if($@) {
    warn("WARNING: Could not create file parser for $aun_file.\n");
    return 'error';
  }
#  my $root_element=&get_root_from_file($aun_file);
  if(not defined($root_element)) {
    warn("WARNING: Could not parse $aun_file.\n");
    next;
  }

  my $person_element=$root_element->getChildrenByTagName('person')->[0];

  # This is why the auma is needed for this function
  $root_element=&AuthorProfile::Common::add_status($root_element, $auma); 
  print "Searching for neighbors for $aunex...\n" if $VERBOSE;

  my @text_elems;
  eval { @text_elems=$root_element->getChildrenByTagName('text'); };
  if($@) {
    if ($VERBOSE > 0) { print("$aun_file bears no accepted texts.\n"); }
    next;
  }
  
  my @hasauthor;
  my $text;
  my $status;
  my $name;

  # Given that the "auverted" /ap record files are being parsed more than once, this should be a global variable.

  my $k=0;
  my $collab_str;
  my $totalNeighbors=0;

  foreach my $text_elem (@text_elems) {
    $text=$text_elem->getAttribute('ref');
    if ($VERBOSE > 0) { print("Parsing text $text...\n"); }

    if(defined($g_parsed_texts->{'t'}->{$text})) {
      if ($VERBOSE > 0) { print("$text already parsed.\n"); }
      next;
    }
    # Find the total amount of authors for this <text/>.

    # This should also be stored into a structure, given the multiple parsing operations that this script undertakes.
    if(not defined($g_parsed_texts->{'k'}->{$text})) { $g_parsed_texts->{'k'}->{$text}=&get_text_total_auth($text_elem); }
    $k=$g_parsed_texts->{'k'}->{$text};
    if($k <= 0) {
      warn("WARNING: Could not find the total amount of authors for $text.\n");
      next;
    }
    if($k == 1) {
      if ($VERBOSE > 0) {  print("Text $text only has one author, skipping $text...\n"); }
      next;
    }
    # Find the collaboration strength by which to increment (the inverse value of) a single edge's weight for this <text/>. 
    $collab_str=1/($k - 1);



    foreach my $name_elem ($text_elem->getChildrenByTagName('hasauthor')) {
      if(not defined($name_elem->getChildrenByTagName('person')->[0])) {
        if ($VERBOSE > 0) { print("<hasauthor/> element bears no <person/> element.\n"); }
        next;
      }
      if(not defined($name_elem->getChildrenByTagName('person')->[0]->getChildrenByTagName('name')->[0])) {
        if ($VERBOSE > 0) { print("<hasauthor/> element bears no <name/> element.\n"); }
        next;
      }
      $name_elem=$name_elem->getChildrenByTagName('person')->[0]->getChildrenByTagName('name')->[0];
      $status=$name_elem->getAttribute('status');

      # Only retrieve aunexes which possess a status of 0
      # This excludes:
      #    identified authors (authors with ACIS profiles)
      #    author-name strings for which there are no "auversion" files
      
      if($status == 0) {

        $name=$name_elem->textContent();
        # Ensure that this isn't the author node for which we're finding neighbors
        next if $name eq $aunex;
        $name=&decode_utf8($name);
        # Store each aunex that lies 1 step away from the author node
        
        if(not defined($aunexes->{'w'}->{$name})) {
          $totalNeighbors++;
          push(@{$aunexes->{'a'}->{$aunex}}, $name);
        }
        $aunexes->{'w'}->{$name}+=$collab_str;
      }
    }
  }

  undef $root_element;
  
  # Calculate the edge weights
  foreach my $aun_2 (keys %{$aunexes->{'w'}}) {
    $aunexes->{'w'}->{$aun_2}=1/($aunexes->{'w'}->{$aun_2});
  }

  print "Found $totalNeighbors neighbors for $aunex.\n" if $VERBOSE;

  return $aunexes;
}

# This is the primary function of the entire script.  It utilizes two functions exported by Network.pm, namely:
# &store_vema_values
# &vert_go_further_from

# As a result, all other functions are really, at this point, unnecessary in this script.  I continue to include these deprecated functions only so that, should I have left something vital outside of the implementation of the current features of this script, I may more easily implement necessary measures by drawing upon previously drafted code.

# The generation of the $vema isn't ended for each author until the
# maxd (referring the maximum binary distance to explore for eaching
# neighboring aunex) is reached by nested loops within the function.
# I purposely avoided the calculation of the resident components for
# each node (as was utilized in the finding of neighboring nodes
# within the script compose_poma), as we are not calculating a
# network, but simply a tree.  The trees for each author with any
# connection to an aunex (a status '0' collaborator for any given
# accepted text) are explored by first cycling through each registered
# author (for which an ACIS record exists), which leads to the aunex
# of every collaborator of every text specified within the ACIS
# records of these authors.  From these aunexes, then, is the tree
# calculated by the exploration of neighboring aunexes found within
# the auverted ap records, first, for each one of these primary
# "aunexes

sub combine_neighbors {

  return 0;

}

sub generate_vema_width_priority {

  my $edges=shift;

  # $edges->{'w'}->{$init_auth}->{$init_aun}=w
  my $poma=shift;
  if(not $poma) { die "poma not passed to gen_vert_width_priority"; }

  my $neighborhoods;
  my $r;

#  print("Maximum exploration depth: $g_maxd\n");
#  <STDIN>;


  foreach my $init_auth (keys %{$edges->{'w'}}) {
    my $total_nodes=(scalar keys %{$edges->{'w'}}) + (scalar keys %{$edges->{'w'}->{$init_auth}});
    print "Beginning with $total_nodes\n";

    foreach my $init_aun (keys %{$edges->{'w'}->{$init_auth}}) {
      my $dist=2;
      # get neighbors
      my $neighbors=find_aunexes_for_aun($init_aun);
      if(not $neighbors) {
        print("No neighbors for $init_aun\n");
        next;
      } elsif ($neighbors eq 'error') { next; }
      # evaluate paths
#      $r=vert_go_further();
      $neighborhoods->{$dist}->{$init_aun}=$neighbors;

    }
    my $explored_distance=(keys %{$neighborhoods})[0] - 1;
    while(($explored_distance + 1) <= $g_maxd) {
      # Check the time limit
      if(($g_init_time - time) >= $g_time_limit) {
        if(not $g_timeout) {
          print("Time limit of $g_time_limit seconds exceeded by the network exploration - ending the exploration.\n");
          $g_timeout=1;
        }
        last;
      }

      $explored_distance++;
      print("Finding all neighbors at a distance of ", $explored_distance + 1, " for $init_auth\n");

      # Clear from memory all neighborhoods that have been explored.
      if(exists $neighborhoods->{$explored_distance - 1}) {
        delete $neighborhoods->{$explored_distance - 1};
      }
      foreach my $primary_aunex (keys %{$neighborhoods->{$explored_distance}}) {

        # Check the time limit
        if(($g_init_time - time) >= $g_time_limit) {
          if(not $g_timeout) {
            print("Time limit of $g_time_limit seconds exceeded by the network exploration - ending the exploration.\n");
            $g_timeout=1;
          }
          last;
        }

        foreach my $neighbor (keys %{$neighborhoods->{$explored_distance}->{$primary_aunex}->{'w'}}) {

          # Check the time limit
          if(($g_init_time - time) >= $g_time_limit) {
            if(not $g_timeout) {
              print("Time limit of $g_time_limit seconds exceeded by the network exploration - ending the exploration.\n");
              $g_timeout=1;
            }
            last;
          }

          print("Finding the neighbors for $neighbor at a distance of ", $explored_distance + 1, " for $primary_aunex\n");
          if(($explored_distance + 1) <= $g_maxd) {
            # get neighbors
            my $new_neighbors=find_aunexes_for_aun($neighbor);
            if(not $new_neighbors) {
              print ("no neighbors found for $neighbor\n");
              next;
            } elsif($new_neighbors eq 'error') { next; }
            $total_nodes+=scalar (keys %{$new_neighbors->{'w'}});
            # Check to see if the exploration has surpassed the maximum node limit
            # This has a higher priority than the time limit
            if($total_nodes > $g_max_nodes) {
              if($g_maxd > 2) {
                $g_maxd--;
                $g_max_nodes_exceeded++;
                warn "Maximum number of nodes exceeded in the exploration of the network - maximum exploration depth set to $g_maxd.\n";
                $total_nodes=(scalar keys %{$edges->{'w'}}) + (scalar keys %{$edges->{'w'}->{$init_auth}});
                print $g_max_nodes - $total_nodes, "nodes until the next maximum is either reached or exceeded.\n";
              }

            }
            elsif(($g_init_time - time) >= $g_time_limit) {
              if(not $g_timeout) {
                print("Time limit of $g_time_limit seconds exceeded by the network exploration - ending the exploration.\n");
                $g_timeout=1;
              }
              last;
            }
            # evaluate paths

            $r=&vert_go_further_from($init_auth, $primary_aunex, $vema, $r, ($explored_distance + 1), $neighbor, $new_neighbors, $poma);

            # $r=vert_go_further_from;
            $neighborhoods->{$explored_distance + 1}->{$neighbor}=$new_neighbors;
          }
        }
      }
    }
  }
  return 0;
}

# The keys will be infinitely increasing unless the limitation upon the generation of new keys from within the loop is limited by a depth condition
# foreach explored_distance keys neighborhoods->{dist}

# foreach aunex keys neighborhoods->explored_distance
# foreach neighbor keys neighborhoods->explored_distance->aunex->{'w'}
# get neighbors
# evaluate paths
# while($dist <= $maxd)
# neighborhoods->explored_distance++->neighbor=new_neighbors

######UNRELATED IDEA
###when max_nodes exceeded with the depth priority approach, do NOT exit the loop, but merely reduce the g_maxd to the distance at which max_nodes was reached
### for added speed, offer an option to reduce the g_maxd by 1 if a global boolean is set

#  while($dist <= $maxd) {
#    foreach my $init_aun (keys $init_neighbors->{'w'}) {
#      my $inner_dist=$dist + 1;
#      my $neighbors;
#      foreach my $neighbor (keys $neighbors->{'w'}) {
        # Evaluate the paths from the author for each one of the neighbors at the distance of $dist.
        # $r can NOT be cleared at any time!
        # This is the only way of building the path to an aunex that lies more than 1 binary step away from an author
        # And this is why I (James) utilize the depth priority method before the width priority method
        # If this proves to create memory problems, then a database or pack file shall have to store the value of $r
        # Otherwise, this approach can not be implemented

        # This stores all neighbors at a distance of 2
#        $r=vert_go_further_from;

#        if($inner_dist <= $maxd) {
#          $inner_dist++;
#          my $new_neighbors;
#        }

#      }
#      next;
#    }
    

#    undef $neighbors;
#    $dist++;
#    next;
#  }


  # Get neighbors at a certain specified distance

  # Store neighbors into a large neighbor structure

  # 



sub find_total_aunexes_to_dist_for_aunex {

  die "find_total_aunexes_to_dist_for_aunex invoked - THIS SHOULD NOT HAPPEN\n";

  my $aunex=shift;
  my $maxd=shift;
  my $max_nodes=shift;

#  my $init_dist=shift;

  my $dist=0;
  my $total_nodes=0;

  my $neighbors=&find_aunexes_for_aun($aunex);

  $total_nodes=scalar keys %{$neighbors->{'w'}};
  if(not $total_nodes) {
    print("No neighbors found for $aunex\n");
    return 0;
  }

  $dist++;
  print "A total of $total_nodes nodes found at dist $dist\n";

  my $counter=1;
  my $index=$total_nodes;

  while($counter <= $index) {

    my $old_index;
    my $old_counter;
    my $old_neighbors;


#    print Dumper $neighbors->{'a'}->{$aunex}[$counter];
#    exit;
#    print "Finding neighbors for $aunex\n";

    my $neighbor=$neighbors->{'a'}->{$aunex}[$counter];
    if(not $neighbor) {
      $counter++;
      next;
    }





    if($dist < $maxd) {

      my $new_neighbors=&find_aunexes_for_aun($neighbor);
      
      if(not $new_neighbors) {
        $counter++;
        next;
      }


      $total_nodes+=scalar keys %{$neighbors->{'w'}};

#      print "Total nodes: $total_nodes at $dist of $maxd\n";
      print "A total of $total_nodes nodes found at dist $dist\n";

      $dist++;

###############################################################
      # FIND_TOTAL_AUN_TO_DIST...  - THIS IS A DEPRECATED FUNCTION

      if($total_nodes > $max_nodes) {

        $g_maxd--;
        print "Maximum breadth exceeded at $dist by ",$total_nodes - $max_nodes, " nodes\n";

        last;
      }

      if($total_nodes > $max_nodes) {
        print "Maximum breadth met at $dist\n";
        last;
      }
###############################################################




      $old_index=$index;
      $old_counter=$counter;
      $old_neighbors->{$dist}=$neighbors;

      $neighbors=$new_neighbors;
      undef $new_neighbors;
      $index=scalar keys %{$neighbors->{'w'}};
      $counter=0;

      next;

    }


#    print $neighbor;
    $counter++;

  }

  print "Finished: $total_nodes\n";
#  print Dumper $neighbors;

}

sub find_t_gen_progress {

  my $t_gen_progress=shift;
  my $current_progress=0;

  foreach my $explored_depth (keys %{$t_gen_progress}) {
    if($current_progress) { $current_progress*=$t_gen_progress->{$explored_depth}; }
    else { $current_progress=$t_gen_progress->{$explored_depth}; }
  }

  $current_progress*= 100;

  print "$current_progress", "% finished generating the network tree at a distance of $g_furthest_depth...\n" if $VERBOSE;

  return $current_progress;
}

sub generate_vema_for_author {

  # Deprecated, from script authored on snefru
  my $edges=shift;
  my $poma=shift;
  my $dist;

  my $tree;
  # Deprecated, from script authored on snefru (was $r)
  # tree structure: Links nodes on a path with adjacent nodes
  # $tree->{'p'}->{BINARY DISTANCE FROM ROOT NODE}->{ADJACENT AUTHOR-NAME STRING}
  # e. g.: $tree->{'p'}->{2}->{'Adam Smith'}='John Smith'
  #
  # O (Adam Smith)
  #  \
  #   O (John Smith)
  #    \
  #     O (ROOT NODE)

  my $author_counter=1;
  # Deprecated, from script authored on snefru
  my $total_authors=scalar(keys %{$edges->{'w'}});

  # For each author in the generated edges...
  foreach my $init_auth (keys %{$edges->{'w'}}) {

    # Start with a distance of 0
    $dist=0;

    $g_furthest_depth=0;

    # Clear the results for vert_go_further_from
    $tree=undef;

    # Manually set $tree to reflect that the $init_auth is 0 steps from itself.
    $tree->{'p'}->{$dist}->{$init_auth}=$init_auth;

    # To give a visualization of the completion of vema exploration.
    print "Processing author $init_auth...\nAuthor $author_counter of $total_authors.\n" if $VERBOSE;

    # The weight of an edge.
    my $weight;

    # To give a visualization of the completion of vema exploration.
    my $aunex_counter=1;

    my $total_aunexes=scalar(keys %{$edges->{'w'}->{$init_auth}});
    $total_aunexes or die 'Fatal: Error in the edges structure';

    my $total_nodes=$total_aunexes;

    # For each initial aunex for the initial author of the tree...
    foreach my $init_aun (keys %{$edges->{'w'}->{$init_auth}}) {

      # Set the distance to 0.
      $dist=1;

      print "Found primary aunex $init_aun for $init_auth...\nPrimary aunex $aunex_counter of $total_aunexes for author $author_counter of $total_authors.\n" if $VERBOSE;

      # Manually set $tree to reflect that the $init_aun is 1 step from $init_auth.
      # The ACIS ID is used as the root node
      # $tree->{'p'}->{1}->{AUTHOR-NAME STRING}=ACIS ID
      $tree->{'p'}->{$dist}->{$init_aun}=$init_auth;

      # The edges structure contains the weights for the edge between this author-name string and the identified author
      $weight=$edges->{'w'}->{$init_auth}->{$init_aun};
      # If the edge weight passed by $edges <= 0, warn the user and exit the script.
      $weight or die "Fatal: Could not find the edge weight between $init_auth and $init_aun";

      # Transfer the edge weight to $tree from $edges.
      $tree->{'w'}->{$init_auth}->{$init_aun}=$weight;
      
      # Manually store the vema values at this point.
      &store_vema_values($init_aun, $init_auth, $dist, $tree, $g_collec_vema);

      my $t_gen_progress;
      
      $t_gen_progress->{$dist}=$aunex_counter/$total_aunexes;

      # structure neighbors: Stores the neighbors for a given author node and the respective edge weights for the paths discovered
      # $neighbors->{'w'}->{node}=weight of edge
      # $neighbors->{'a'}->[nodes]
      # Find the neighbors for the initial aunex.
      my $neighbors=find_aunexes_for_aun($init_aun);
      if(not $neighbors) {
        warn "Warning: Could not find any neighbors for $init_aun" if $VERBOSE;
        next;
      }

      # The previous aunex at this point in the loop is the initial author (distance 0).

      # structure previousAuthorNode: Stores the structure of the path being explored
      # previousAuthorNode->{BINARY DISTANCE FROM ROOT NODE}=AUTHOR NODE
      # previousAuthorNode->{0}=ACIS ID
      # previousAuthorNode->{1}=Author-name String
      my $old_aunex->{$dist}=$init_auth;
      $old_aunex->{$dist + 1}=$init_aun;

      # structure lastDiscoveredNeighborIndex: Stores the index of the node within the neighborhood discovered
      # lastDiscoveredNeighborIndex->{BINARY DISTANCE FROM THE ROOT NODE}=NODE INDEX
      my $old_inner_counter;
      # lastDiscoveredNeighborIndex->{0}=0 (There is only one root node)
      $old_inner_counter->{$dist}=$author_counter;
      # lastDiscoveredNeighborIndex->{1}=0 (Zero-based indexing of arrays and counters)
      $old_inner_counter->{$dist + 1}=$aunex_counter;

      # structure lastDiscoveredNeighborhoodSize: Stores the number of nodes in the last neighborhood discovered
      my $old_n_index;
      $old_n_index->{$dist}=$total_authors;
      $old_n_index->{$dist + 1}=$total_aunexes;

      my $stored_neighbors;

      # The first aunex to explore the neighbors of is the initial aunex (dist 1).
      my $aunex=$init_aun;
      my $i=1;


      my $probe_dist=$dist + 1;

      # structure neighborsDiscovered: Stores the array of neighbors discovered for an author node
      $stored_neighbors->{$probe_dist}=$neighbors;

      # Store the number of neighbors found for the initial aunex.
      my $n_i=scalar(keys %{$neighbors->{'w'}});

      # Initialize $dist_2 with a value of 1 (dist 1).
      my $new_neighbors;

      my $i_2=1;
      my $inner_counter=0;
        
      my $n_index=undef;

      my $aunex_probe=undef;


###################################################################################################

      # This is the primary recursion of the script - the exploration of this "tree" within the network terminates once a certain depth has been met.

      while($probe_dist > 0) {

        $aunex or die "Fatal: Null \$aunex found at $probe_dist";
        
        # If there are no $neighbors for $n_aun at this point and $dist_2 <= 2, exit the loop.
        # This would mean that the exploration has exhausted all of the aunexes found for the primary aunex at this point.  Hence, the next primary aunex must, then, be explored.
        
        # If $n_aun__2 has been defined, then the inner loop has already run at least once.
        if(defined($aunex_probe)) {

          # 03/05/11 - Avoiding memory leak.
          $tree->{'p'}->{$probe_dist}=undef;
          $tree->{'w'}->{$aunex}=undef;

          # ?
          if($probe_dist == ($dist + 1)) { last; }

          # Decrement the distance of the exploration...
          $probe_dist--;
          # ...so that the explorations can return to the previous neighborhood,...
          $neighbors=$stored_neighbors->{$probe_dist};
          # ...the size of the last neighborhood can be retrieved,...
          $n_index=$old_n_index->{$probe_dist};
          # ...the last node index can be retrieved,...
          $inner_counter=($old_inner_counter->{$probe_dist}) + 1;
          # ...and the last aunex discovered can be retrieved.
          $aunex=$old_aunex->{$probe_dist};
          # Now, the exploration can resume from the previous neighborhood

          # While there is no 

          # stored_neighbors->{'a'}->{last_aunex}->[old neighborhood index + 1]
          while(not defined(($stored_neighbors->{$probe_dist})->{'a'}->{$old_aunex->{$probe_dist}}->[(($old_inner_counter->{$probe_dist}) + 1)])) {

            # 03/05/11 - Avoiding memory leak.
            $tree->{'p'}->{$probe_dist}=undef;
            $tree->{'w'}->{$aunex}=undef;

            if($probe_dist == ($dist + 1)) {

              # 03/05/11 - Avoiding memory leak.
              $stored_neighbors=undef;
              # 03/05/11 - Avoiding memory leak.
              $neighbors=undef;
              # Might not be necessary, as both variables probably lose their value after breaking from the current loop.
              last;
            }

            $probe_dist--;
            $neighbors=$stored_neighbors->{$probe_dist};
            $aunex=$old_aunex->{$probe_dist};
            $n_index=$old_n_index->{$probe_dist};
            $inner_counter=($old_inner_counter->{$probe_dist}) + 1;
          }
          # 03/05/11 - Avoiding memory leak.
          $stored_neighbors->{($probe_dist + 1)}=undef;
        }

        if(not defined($n_index)) {
          if(not $neighbors->{'a'}->{$aunex}) {
            last;
          }
          $n_index=scalar(@{$neighbors->{'a'}->{$aunex}});
        }
        
########################################################

        # This loop ends when every aunex held within neighbors has been explored.
        # This ensures that each and every neighbor within a neighborhood is fully explored.
        while($inner_counter < $n_index) {

          # If the maximum distance hasn't been reached, increment the distance (as we are about to go further into the network).

          #For visualization of generation progress.
          my $nnum=$inner_counter + 1;
          my $ntot=$n_index;

          # $n_aun__2 is now the neighbor corresponding to the index $i_3 within the neighborhood stored by $neighbors.
          $aunex_probe=$neighbors->{'a'}->{$aunex}->[$inner_counter];



          if ($VERBOSE > 0) { print("generate_vema: Probing $aunex_probe \(neighbor $nnum of $ntot\) for $aunex at distance $probe_dist from $init_aun \($aunex_counter of $total_aunexes\) from $init_auth \($author_counter of $total_authors\).\n"); }

          # Construct the vema path for $n_aun__2 and store it in the vema database.
          $tree=&vert_go_further_from($init_auth, $aunex, $vema, $tree, $probe_dist, $aunex_probe, $neighbors, $poma);

          # Continue exploring further if the maximum distance has yet to be reached.
          if($probe_dist < $g_maxd) {

            # ...set the structure $new_neighbors to the $neighbors of the current secondary aunex...
            $new_neighbors=&find_aunexes_for_aun($aunex_probe);
            if($new_neighbors eq 'error') { next; }

            # Check to see if $n_aun__2 is an isolated aunex.
            if(not keys %{$new_neighbors->{'w'}}) {
              # If so, move to the next secondary aunex that isn't isolated.

              if ($VERBOSE > 0) { print("generate_vema: Skipping isolated neighbor $aunex_probe...\n"); }
              $inner_counter++;
              # 03/05/11 - Avoiding memory leak.
              $new_neighbors=undef;
              next;
            }

            # First, before going forward, store the previous set of neighbors.
            $stored_neighbors->{$probe_dist}=$neighbors;
            $old_aunex->{$probe_dist}=$aunex;
            # Store index of the last neighborhood.
            $old_n_index->{$probe_dist}=$n_index;
            # Store the old neighborhood index counter.
            $old_inner_counter->{$probe_dist}=$inner_counter;

            $probe_dist++;

            $g_furthest_depth=$probe_dist if $probe_dist > $g_furthest_depth;
            print "generate_vema: Exploring the neighbors for $aunex_probe...\n" if $VERBOSE;

            # Set the neighbors to the newly found neighbors for the loop.
            $neighbors=$new_neighbors;
            $new_neighbors=undef;

            # Set the predecessor aunex to the current aunex used for exploration.
            $aunex=$aunex_probe;

            die "FATAL ERROR: \$aunex not defined.\n" if not $aunex;

            # Set the new neighborhood index.
            $n_index=scalar(@{$neighbors->{'a'}->{$aunex}});

            if($total_nodes + $n_index > $g_max_nodes) {
              if($g_maxd > 2) {
                $g_maxd--;
                $g_max_nodes_exceeded++;
              }

              warn "WARNING: Maximum neighbor nodes exceeded at $probe_dist - maximum node depth set to $g_maxd.\n";
            }
            else {
              $total_nodes+=$n_index;
            }

            # Reset the index counter for the next neighbordood.
            $inner_counter=0;
            
            # Move to the next neighborhood.
            next;
          }
          # If we're at the maximum distance, just explore every neighbor in the terminal neighborhood.
          else {
            $inner_counter++;
          }
        }
        
###########################################################################

        # The neighborhood has been explored.  This could be any neighborhood, not just the terminal one.
        print "The inner loop has finished for the exploration of neighbors lying one step away from $aunex \(which is a distance of $probe_dist from $init_auth\).\n" if $VERBOSE;
        next;
      }
#####################################################################
      print "Finished exploring all neighbors for $init_aun\n" if $VERBOSE;
      $aunex_counter++;
      next;
    }
#####################################################################
    print "Finished exploring all aunexes for author $init_auth.\n" if $VERBOSE;
    $author_counter++;
    next;
  }
#####################################################################
  return $vema;
}





#####################################################

# The Main function of the script


sub main {

  &proc_input(\@ARGV);

  &init_auma();

  &init_edges();



  if(not $g_input) {

    # If there is no file supplied, parse the record for Thomas Krichel:
    $g_input="$ap_dir/k/r/pkr1.amf.xml";

    print("No file\(s\) passed, processing $g_input...\n") if $VERBOSE;

    &parse_file($g_input);

    # Deprecated due to the vertical wrapper:
    #      print("No files passed, processing $ap_dir...\n");
    #    $g_all_auth=1;
    #    &parse_dir($ap_dir);

    return 0;
  }

  if(-d $g_input) {
    &parse_dir($g_input);
    return 0;
  }    
  if(-f $g_input) {
    &parse_file($g_input);
    return 0;
  }

  warn("Error: path $g_input not found...\n");
  return 1;
}

sub vert_go_further_from {

  my $init_auth=shift;
  my $i_aun=shift;
  # $vema_values is deprecated - I have forgotten why this was here, but it should be removed.
  my $vema_values=shift;
  my $r=shift;
  my $dist=shift;
# This was generated by &find_aunexes_for_aun.
  my $n_aun=shift;
  my $neighbors=shift;
  my $poma=shift;
  my $verbosity=$VERBOSE;
  my $dry_run=$DEBUG;

  my $w=0;
  my $i=1;

  my $n_i=scalar(keys %{$neighbors->{'w'}});


  die "vert_go_further_from: FATAL ERROR: \$n_aun not passed.\n" if not $n_aun;


  my $vema_key=normalize_name($n_aun);
  my $vema=&vema_db_retrieve($vema_key, $g_collec_vema);



  if(not $r or not defined($r->{'p'}->{$dist}->{$n_aun})) {
    #This is still needed to construct the vema path...
    $r->{'p'}->{$dist}->{$n_aun}=$i_aun;
  }
  
  # The weight for the neighbors structure was not stored as a symmetric weight value, but instead, as simply the summation of the total amount of collaborating authors for each paper collaborated upon by the authors to whom the aunexes being compared belong.  I am not sure what my reasoning behind this was at the time, but it may be unnecessary.

  $w=$neighbors->{'w'}->{$n_aun};

  $w > 0 ? $r->{'w'}->{$i_aun}->{$n_aun}=$w : die "FATAL ERROR: Edge weight for $i_aun and $n_aun could not be found.\n", Dumper $neighbors;

  # switch...case n...break



  # If a vema path has already been stored into the database...
  if($vema) {

    print "\nDEBUG: Path from $n_aun to $init_auth at a distance of $dist is longer than $vema->{'p'} at a distance of $vema->{'d'}\n\n" if $vema->{'d'} < $dist;

    # ...first check to see if the stored path is of a greater length that the path just generated for the aunex being explored...
    if($vema->{'d'} > $dist) {
        
      print "vert_go_further_from: A shorter path has been found for $n_aun from $i_aun.\n" if $VERBOSE;
      # ...and store the newly calculated path if it is indeed shorter.
      &store_vema_values($n_aun, $init_auth, $dist, $r, $g_collec_vema) if not $dry_run;
    }
    # ...otherwise, if the length of the vema path is equal to the path that has been stored...
    elsif($vema->{'d'} == $dist) {

      # ...and if the weight is less than the stored path...
      if($vema->{'w'} > $r->{'w'}->{$i_aun}->{$n_aun}) {

        #...store the newly calculated vema path.
        print "A lighter path has been found for $n_aun from $i_aun.\n" if $VERBOSE;
        &store_vema_values($n_aun, $init_auth, $dist, $r, $g_collec_vema) if not $dry_run;        
      }
      # ...or, if the distance is the same but the weight of the newly calculated path is greater than the stored vema path, compare, then, use the poma for a conmparison...
      elsif($vema->{'e'} ne $init_auth and &compare_nodes_using_poma($vema->{'e'}, $init_auth, $poma) eq $init_auth) {

        # and if the preferred author is the initial node of this path, store the newly calculated vema path.
        print "A more direct path has been found for $n_aun from $i_aun.\n" if $VERBOSE;
        &store_vema_values($n_aun, $init_auth, $dist, $r, $g_collec_vema) if not $dry_run;
      }
      else {
        print "\nDEBUG: This path was already discovered.\n\n";
      }
    }
  }
  # ...and if the path hasn't been stored into the vema database at all, store the path.
  else {

    print "New path found for $n_aun from $i_aun.\n" if $VERBOSE;
    &store_vema_values($n_aun, $init_auth, $dist, $r, $g_collec_vema) if not $dry_run;
  }
  $i++;

  $vema=undef;
  return $r;
}


sub update_noma_log {

  if(not -f $g_noma_log_file) {
    `touch $g_noma_log_dir/$g_noma_log_file`;
    die $!;
  }

  my $noma_db_file=shift;
  my $sid=shift;
  my $noma_record_field=shift;
  my $noma_record_value=shift;
  my $time=time;

  

  `echo "$time: noma database in $noma_db_file: record for $sid: value $noma_record_value stored in $noma_record_field\n" >> $g_noma_log_file`;

}

sub proc_args {

  my $input_var=shift;

##################################
# Exact string comparisons
##################################

  # Deprecated: This is a default setting.
#  if($input_var eq '--no-edges') {
#    $STORE_EDGES=0;
#    return;
#  }

  if($input_var eq '--store-edges') {
    $STORE_EDGES=1;
    return;
  }

  if($input_var eq '--forced-auma-regen') {
    $REGEN_AUMA=1;
    return;
  }
  if($input_var eq '-q' or $input_var eq '--quiet') {
    $VERBOSE=0;
    return;
  }
  if($input_var eq '--dry-run') {
    $DEBUG=1;
    return;
  }

##################################
# Regexp operations
##################################

  if($input_var=~m|--maxd=| or $input_var=~m|-d|) {
    my $maxd=$input_var;
    $maxd=~s|--maxd=||;
    $maxd=~s|-d||;
    $maxd or die "Fatal Error: No maximum distance (--maxd / -d) value passed.\n";
    $MAX_DIST=$maxd if $maxd > 1;
    print "Maximum distance set to $maxd\n" if $VERBOSE;
    return;
  }

##################################

  die "Unrecognized argument '$input_var' passed.\n";
  return;
}


sub proc_input {
  my $args=shift;
  foreach my $input_var (@ARGV) {
    # $input_var = shift @{$input_var};
    if(not defined($g_input)) {
      if(-f $input_var or -d $input_var) {
        $g_input=$input_var;
        next;
      }
      else {
        &proc_args($input_var);
      }
    }
  }
}
