#!/usr/bin/perl

## enforce strict pragma
use strict;
## warn about possible problem
use warnings;

use lib qw( /home/aupro/ap/perl/lib /home/aupro/usr/lib/perl );

## used modules, in alphabetical order
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

my $g_verbose=3;

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

#my $home_dir=$ENV{'HOME'};

######################################

# Input directory and file paths
#my $auma_pack_file="$home_dir/ap/var/auma.json";
#my $g_poma_file="$home_dir/ap/var/poma.json";
#my $acis_dir="$home_dir/ap/amf/3lib/am";
#my $ap_dir="$home_dir/ap/amf/auverted";
my $g_log_dir="$home_dir/ap/var/log/vertical";

#my $g_poma_script="$home_dir/ap/perl/bin/generate_poma";
my $g_vert_stat_file="$home_dir/ap/var/vims.json";

#if(not -f $g_vert_stat_file) {
#  print "Generating poma...\n" if $g_verbose;
#  `$g_poma_script`;
#  die;
#  eval { `$g_poma_script`; };
#  if($@) { die $! or "Could not create VI metadata file\n"; }
#}

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

# Output directory and file paths

## Berkeley::Env no longer used - too many errors.
#my $g_vema_db_dir='/opt/wotan/home/mamf/opt/var/vertical';
#my $g_vema_db_file='vema.db';

my $g_vema_db_dir="$home_dir/ap/var";

if(not -d $g_vema_db_dir) {

  eval { `mkdir $g_vema_db_dir`; };
  if($@) { die $!; }

  if(not -d $g_vema_db_dir) { die "Fatal Error: Could not create $g_vema_db_dir!"; }
}

my $g_vema_db_file="$g_vema_db_dir/vema.db";

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

# FAR too few nodes
#my $g_max_nodes=10000;
my $g_max_nodes=100000000;

my $g_node_increment=0.1;



my $g_statuses_found=undef;
my $g_aunexes=undef;
my $g_all_auth=0;
my $g_parsed_texts=undef;

my $g_input=undef;

my $g_parsing_dir=0;

my $g_dry_run=0;
my $g_width_p=0;

my $g_init_time=time;
my $g_time_limit=604800;

my $g_time_increment=0.1;
# FAR too little time
#my $g_time_limit=86400;

my $g_max_nodes_exceeded=0;

my $g_timeout=0;

my $g_furthest_depth;

my $g_furthest_depth_explored=0;

#########################################

# The auma (author name expression matrix data structure)

my $auma=undef;
my $auma_gen="$home_dir/ap/perl/bin/ap_top";
# Flag for forcing the regeneration of the auma.

my $g_force_auma_regen=0;

sub init_auma {
  ## check if auma is old,
  if(not -f $auma_file or (-M $auma_file) > 1 or $g_force_auma_regen == 1) {
    if($g_verbose > 1) { 
      print("\(Re\)generating the \$auma...\n"); 
    }
#    my $refresh_auma_results=`$auma_gen`;
    if($g_verbose > 1) { 
      print("Retrieving the \(re\)generated \$auma...\n"); }
#    $auma=mp_retrieve($auma_pack_file);
    $auma=AuthorProfile::Common::json_retrieve($auma_file);
  }
  else {
    if($g_verbose > 1) { print "loading auma\n"; }
#    $auma=mp_retrieve($auma_pack_file);
    $auma=AuthorProfile::Common::json_retrieve($auma_file);
  }
  
}

#########################################

# The poma (pecking order matrix data structure)

my $poma=undef;

my $g_force_poma_regen=0;

# Retrieving the $poma from /poma.pack
# NOTE: This assumes that the poma.pack is still refreshed according to crontab

#eval { $poma=mp_retrieve($poma_pack_file); };
generate_poma if not -f $poma_file;

#eval { $poma=json_retrieve($g_poma_file); };

$poma=AuthorProfile::Common::json_retrieve($poma_file);

#die Dumper $poma;

die "FATAL ERROR: Could not retrieve poma structure at $poma_file - $!\n" if $@;



#########################################

# The vema (vertical information matrix data structure)

# $vema->{DEST}->{'d'} = distance to START node, in binary steps.
# $vema->{DEST}->{'p'} = a space separeted path of intermediate nodes
# $vema->{DEST}->{'e'} = START
# $vema->{DEST}->{'w'} = weight of the path
# DB's are values
# the keys are the identifiers of the target node
# they are NOT the identifiers of the source nodes!
# they, essentially, convert the source node to target nodes

my $vema=undef;

# Construct the BerkDB ENV

#my $g_vema_db_env;
#eval { $g_vema_db_env = new BerkeleyDB::Env
#                  -Home   => $g_vema_db_dir,
#                  -Flags  => DB_CREATE| DB_INIT_CDB | DB_INIT_MPOOL
#  or die "cannot open database: $BerkeleyDB::Error\n"; };
#if($@) { die $!; }

my $g_vema_db_file_path=undef;

# Construct the handler-object for the BerkDB that stores the $vema values
my $g_vema_db = new BerkeleyDB::Hash
  -Filename => $g_vema_db_file,
  -Flags    => DB_CREATE
  or die "cannot open database: $BerkeleyDB::Error\n";

#########################################

# The noma ("node master" matrix data structure)
# $noma->{[SID]}->{'last_change_date'}
# $noma->{[SID]}->{'began_calculation'}
# $noma->{[SID]}->{'ended_calculation'}
# $noma->{[SID]}->{'furthest_depth'}

# James proposes:
# $noma->{[SID]}->{'last_path'}

my $g_noma_db_file="$g_vema_db_dir/noma.db";

my $g_noma_log_dir=$g_log_dir;
my $g_noma_log_file='noma.log';

if(not -f $g_noma_db_file) { die "noma database $g_noma_db_file does not exist.\n"; }

# Construct the handler-object for the BerkDB that stores the $noma values
my $g_noma_db = new BerkeleyDB::Hash
  -Filename => $g_noma_db_file,
  -Flags    => DB_CREATE
  or die $BerkeleyDB::Error;

#########################################

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
my $edges_tmp_pack_file="$home_dir/ap/var/vertical_edges.json";
my $g_store_edges=0;

sub init_edges {
  if($g_store_edges == 1 and -f $edges_tmp_pack_file) {
#    $edges=mp_retrieve($edges_tmp_pack_file);
    $edges=AuthorProfile::Common::json_retrieve($edges_tmp_pack_file);
  }
}



#########################

# The invocation of the main() function.
&main();

#########################

sub parse_dir {
  my $dir=$_[0];
  if(not defined($dir)) {
    return 1;
  }
  $g_parsing_dir=1;
  # TO DO: recursion!
  my @files=`find $dir -name '*.amf.xml'`;
  shuffle(@files);
  foreach my $file (@files) {
    chomp $file;
    if ($g_verbose > 0) { print("Processing $file...\n"); }
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

  if($g_dry_run) { if($g_verbose) { print "\"Dry run\" mode enabled: No transactions with the vertical integration database will be performed.\n"; } }

#    if(not defined($edges)) {
#      if($record_type == 0) { $edges=&find_aun_for_auth_texts($auma, $file); }
#      elsif($record_type == 1) {
#        $edges=&find_aun_for_aun_text($root_elem, $auma);
#      }
#    }
    
#    $edges=undef;
#    $root_elem=undef;
#    $doc=undef;
    
#    if ($g_verbose) { print("Vertical integration data successfully generated for $file.\n"); }
#    return 0;
#  }



  if(not $g_dry_run) {
    
    my $vert_stat_obj;
#    eval { $vert_stat_obj=json_retrieve($g_vert_stat_file); };
#    if($@) { warn "could not retrieve vert_stat.json: $!"; }

#    if(not -f $g_vert_stat_file) {
#      print "Creating $g_vert_stat_file...";
#      eval { `touch $g_vert_stat_file`; };
#    } else { 

#    if(not is_file_empty($g_vert_stat_file)) {
    if(-s $g_vert_stat_file) {
      eval { $vert_stat_obj=AuthorProfile::Common::json_retrieve($g_vert_stat_file); };
      if($@) { die $! or die "Could not access $g_vert_stat_file"; }
    }

#    elsif(not $vert_stat_obj) { warn "could not retrieve vert_stat.json\n"; }

    if($vert_stat_obj->{$sid}) {
      my $vert_time=$vert_stat_obj->{$sid}->{$g_maxd}->{'time_elapsed'};
      my $vert_nodes=$vert_stat_obj->{$sid}->{$g_maxd}->{'max_nodes_exceeded'};
      if($vert_time) {
        #Increase the time limit by g_time_increment
        $g_time_limit+=$vert_time * $g_time_increment * $g_time_limit;
      }
      if($vert_nodes) {
        $g_max_nodes*=$vert_nodes * $g_node_increment * $g_max_nodes;
        #Increase the time limit by g_time_increment
      }
    }


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

    # This distinguishes between ACIS records and auverted /ap records.
    foreach my $root_attr ($root_elem->attributes()) {
      #    if($root_attr->getData() eq 'http://acis.openlib.org/2007/doclinks-relations') { $record_type=0; }
      if($root_attr->getData() eq $g_acis_root_attr_const) { $record_type=0; }
      else { $record_type=1; }
    }

    # If the values for $edges was not retrieved from the .tmp.pack file...
    if(not defined($edges)) {
      # ...generate them anew...
      if($record_type == 0) { $edges=&find_aun_for_auth_texts($auma, $file); }
      elsif($record_type == 1) {
        #      my $tmp_aunex=&get_aunexes_from_auverted_record($root_elem);
        $edges=&find_aun_for_aun_text($root_elem, $auma);
      }
    }

    if($g_width_p) { &generate_vema_width_priority($edges, $poma); }

    &generate_vema($edges, $poma);

    # generate_vema_width_priority still must be debugged
    
    #  if($g_max_nodes_exceeded or $g_timeout) { &generate_vema_width_priority($edges, $poma); }

    $edges=undef;
    $root_elem=undef;
    $doc=undef;
    
#    $noma_record->{'furthest_depth'}=$g_maxd + $g_max_nodes_exceeded;
    if((not $g_timeout) and (not $g_max_nodes_exceeded)) {
      
      my $ended_calc_time=time();

      # Temporarily disabled
      #if(update_noma_values($sid,$g_collec_noma,\@{['ended_calculation','furthest_depth']},\@{[$ended_calc_time,$g_maxd]})) {
        #die "Fatal Error: Could not update the noma values for $sid";
      #}

      # Possibly unnecessary...
      if(update_noma_values($sid,$g_collec_noma,'ended_calculation',$ended_calc_time)) {
        die "Fatal Error: Could not update the noma values for $sid";
      }
      if(update_noma_values($sid,$g_collec_noma,'furthest_depth',$g_maxd)) {
        die "Fatal Error: Could not update the noma values for $sid";
      }
    }
  }

    # I need to address this after MongoDB is functioning properly.

    ##########
#  } else {

      # To do / fixme: use ternary operator instead of this convoluted approach (I am tired)
 #     my $vert_stat_obj;

#      eval { $vert_stat_obj=json_retrieve($g_vert_stat_file); };
#      if($@) { warn "could not retrieve vert_stat.json: $!"; }

#      if(not -f $g_vert_stat_file) {
#        print "Creating $g_vert_stat_file...";
#        eval { `touch $g_vert_stat_file`; };
#      } else { eval { $vert_stat_obj=json_retrieve($g_vert_stat_file); }; }
#      if($@) { warn $! or warn "Could not access $g_vert_stat_file"; }

#      elsif(not $vert_stat_obj) { warn "could not retrieve vert_stat.json\n"; }

#      if(not is_file_empty($g_vert_stat_file)) {
#      if(-s $g_vert_stat_file) {
#        eval { $vert_stat_obj=AuthorProfile::Common::json_retrieve($g_vert_stat_file); };
#        if($@) { die $! or die "Could not access $g_vert_stat_file"; }
#      }
#      if($g_timeout) {
#        $vert_stat_obj->{$sid}->{$g_maxd}->{'time_elapsed'}+=1;
#      }
#      if($g_max_nodes_exceeded) {
#        $vert_stat_obj->{$sid}->{$g_maxd}->{'max_nodes_exceeded'}+=1;
#      }
#      AuthorProfile::Common::json_store($vert_stat_obj, $g_vert_stat_file);
#    }
#  }

#  $g_noma_db=&AuthorProfile::Common::open_db($g_noma_db_file);
#  my $noma_record=&AuthorProfile::Common::get_from_db_json($g_noma_db,$sid);
  #    $noma_record->{'furthest_depth'}=$g_maxd + $g_max_nodes_exceeded;
#  my $ended_calc_time=time();
#  $noma_record->{'ended_calculation'}=$ended_calc_time;
#  &AuthorProfile::Common::put_in_db_json($g_noma_db,$sid,$noma_record);
#  &AuthorProfile::Common::close_db($g_noma_db);
  
  if ($g_verbose > 0) { print("Vertical integration data successfully generated for $file.\n"); }

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

sub find_aun_for_auth_texts {

  my $aun_auth_papers;

  # Global structure
  my $auma=shift;
#  my $auth_file=shift;

  my $input_files=shift;

  my @files;
  $files[0]=$input_files;

# The edges are to be calculated for each record as each record is processed.

#  if($all_auth) {
#    @files=undef;
#    @files=`find $acis_dir -name '*.amf.xml'`;
#  }

  foreach my $file (@files) {
    chomp $file;
    if ($g_verbose > 0) { print("Processing $file...\n"); }

    my $root_element=AuthorProfile::Common::get_root_from_file($file);
    if(not defined($root_element)) {
      warn("WARNING: Could not parse $file.\n");
      next;
    }

    my $person_element=$root_element->getChildrenByTagName('person')->[0];

    # 01/14/11 Get the sID of the author whose information this record holds.
    my $owner_id=$person_element->getChildrenByTagNameNS($acis_ns, 'shortid')->[0]->textContent();

    # 01/11/11 - James: Obtain statuses in order to differentiate between unregistered and registered authors.
    $root_element=&AuthorProfile::Common::add_status($root_element,$auma); 

    my @text_elems;
    eval { @text_elems=$root_element->getChildrenByTagName('person')->[0]->getChildrenByTagName('isauthorof'); };
    if($@) {
      if ($g_verbose > 0) { print("$file bears no accepted texts.\n"); }
      next;
    }


    my $parsed_texts;

    my @hasauthor;
    my $text;



    my $status;
    my $name;
    my $k;
    my $collab_str;
    foreach my $text_elem (@text_elems) {
      $text_elem=$text_elem->getChildrenByTagName('text')->[0];
      $text=$text_elem->getAttribute('ref');
      if ($g_verbose > 0) { print("Processing $text...\n"); }
      if(defined($parsed_texts->{$text})) {
        if ($g_verbose > 0) { print("$text already parsed.\n"); }
        next;
      }
      # Find the total amount of authors for this <text/>.
      $k=&get_text_total_auth($text_elem);
      if($k <= 0) {
        warn("WARNING: Could not find the total amount of authors for $text.\n");
        next;
      }
      if($k == 1) {
        if ($g_verbose > 0) { print("$text only has one author, skipping $text...\n"); }
        next;
      }
      # Find the collaboration strength by which to increment (the inverse value of) a single edge's weight for this <text/>. 
      $collab_str=1/($k - 1);

      foreach my $name_elem ($text_elem->getChildrenByTagName('hasauthor')) {
        $name_elem=$name_elem->getChildrenByTagName('person')->[0]->getChildrenByTagName('name')->[0];
        $status=$name_elem->getAttribute('status');
        if($status == 0) {
          $name=$name_elem->textContent();
          $name=&decode_utf8($name);
          $name=normalize_name($name);
          if(not defined ($aun_auth_papers->{'w'}->{$owner_id}->{$name})) {
            if ($g_verbose > 0) { print("Found primary aunex $name for author $owner_id.\n"); }
          }
          $aun_auth_papers->{'w'}->{$owner_id}->{$name}+=$collab_str;
        }
      }
      my $txttot=$#text_elems + 1;
      if ($g_verbose > 0) { print("Found a total of $txttot texts for author $owner_id.\n"); }
    }
  }

  # Calculate the symmetric weighted edges between authors and primary aunexes by finding the inverse value of the summation of the collaboration strengths obtained for every <text/> collaborated upon by both author $owner_id and aunex $name.
  foreach my $auth (keys %{$aun_auth_papers->{'w'}}) {
    foreach my $aun (keys %{$aun_auth_papers->{'w'}->{$auth}}) {
      $aun_auth_papers->{'w'}->{$auth}->{$aun}=1/($aun_auth_papers->{'w'}->{$auth}->{$aun});
    }
  }
  
#  if($g_store_edges) { mp_store($aun_auth_papers, $edges_tmp_pack_file); } 
  if($g_store_edges) { AuthorProfile::Common::json_store($aun_auth_papers, $edges_tmp_pack_file); } 
  
  return $aun_auth_papers;
}

sub get_text_total_auth {
  my $text_elem=shift;
  my $collab_str=0;
  foreach my $name_elem ($text_elem->getChildrenByTagName('hasauthor')) {
    $collab_str++;
  }
  return $collab_str;
}

sub find_aun_for_aun_text {

  my $aun_aun_edges;

  # Global structure

  # This processes one auverted record per invocation.
  my $root_element=shift;

  my $auma=shift;

  if ($g_verbose > 0) { print("Processing auverted record...\n"); }

## NOTE RETURN HERE

  $root_element=&AuthorProfile::Common::add_status($root_element, $auma); 

  my @text_elems;
  eval { @text_elems=$root_element->getChildrenByTagName('text'); };
  if($@) {
    if ($g_verbose > 0) { print("Auverted record bears no accepted texts.\n"); }
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
  my $neighbors=undef;
  my $total_neighbors=undef;

  foreach my $text_elem (@text_elems) {
    $text=$text_elem->getAttribute('id');
    if ($g_verbose > 0) { print("Processing $text...\n"); }
    if(defined($parsed_texts->{$text})) {
    }
    $k=&get_text_total_auth($text_elem);
    if($k <= 0) {
      warn("WARNING: Could not find the total amount of authors for $text.\n");
      next;
    }
    if($k == 1) {
      if ($g_verbose > 0) { print("$text only has one author, skipping $text...\n"); }
      next;
    }
    # Find the collaboration strength by which to increment (the inverse value of) a single edge's weight for this <text/>. 
    $collab_str=1/($k - 1);

    
    foreach my $name_elem ($text_elem->getChildrenByTagName('hasauthor')) {
      $name_elem=$name_elem->getChildrenByTagName('person')->[0]->getChildrenByTagName('name')->[0];
      $status=$name_elem->getAttribute('status');
      if($status == 0) {
        $name=$name_elem->textContent();
        # The primary aunex, in this case, is merely the aunex specified in the auverted record being parsed.
        $name=&decode_utf8($name);
        $name=normalize_name($name);
#        print $name, "\n";
#        exit;

        $init_aun=$name;
        


        # From here, obtain all of the neighbors

        if ($g_verbose > 0) { print("Found author $init_aun.\n"); }

        $neighbors=&find_aunexes_for_aun($init_aun);
        if($neighbors eq 'error') { next; }

        foreach my $prim_aun (keys %{$neighbors->{'w'}}) {
          if(not defined ($aun_aun_edges->{'w'}->{$init_aun}->{$prim_aun})) {
            if ($g_verbose > 0) { print("Found primary aunex $prim_aun for initial aunex $init_aun.\n"); }
            $aun_aun_edges->{'w'}->{$init_aun}->{$prim_aun}=$neighbors->{'w'}->{$prim_aun};
          }
        }
      }
    }
  }
  my $txttot=$#text_elems + 1;
  if ($g_verbose > 0) { print("Found a total of $txttot texts specified for the auverted record.\n"); }

  # $aun_aun_edges->{'w'}->{$aun_1}->{$aun_2}
  
  # Calculate the symmetric weighted edges between authors and primary aunexes by finding the inverse value of the summation of the collaboration strengths obtained for every <text/> collaborated upon by both author $owner_id and aunex $name.
  foreach my $aun_1 (keys %{$aun_aun_edges->{'w'}}) {
    foreach my $aun_2 (keys %{$aun_aun_edges->{'w'}->{$aun_1}}) {
      $aun_aun_edges->{'w'}->{$aun_1}->{$aun_2}=1/($aun_aun_edges->{'w'}->{$aun_1}->{$aun_2});
    }
  }
  
#  if($g_store_edges) { mp_store($aun_aun_edges, $edges_tmp_pack_file); } 
  if($g_store_edges) { AuthorProfile::Common::json_store($aun_aun_edges, $edges_tmp_pack_file); } 
  
  return $aun_aun_edges;
}


sub get_aunexes_from_auverted_record {

  my $root_element=shift;

  my $person_element=$root_element->getChildrenByTagName('person')->[0];

  $root_element=&AuthorProfile::Common::add_status($root_element, $auma); 

  if ($g_verbose > 0) { print("Searching for the first aunex in the auverted record...\n"); }

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
    if ($g_verbose > 0) { print("Parsing text $text...\n"); }

    foreach my $name_elem ($text_elem->getChildrenByTagName('hasauthor')) {
      if(not defined($name_elem->getChildrenByTagName('person')->[0])) {
        if ($g_verbose > 0) { print("<hasauthor/> element bears no <person/> element.\n"); }
        next;
      }
      if(not defined($name_elem->getChildrenByTagName('person')->[0]->getChildrenByTagName('name')->[0])) {
        if ($g_verbose > 0) { print("<hasauthor/> element bears no <name/> element.\n"); }
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

  if(not defined($aunex)) {
    warn("WARNING: Empty value for \$aunex passed to find_aun_for_aun.\n");
    return 'error';
  }

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

  $root_element=&AuthorProfile::Common::add_status($root_element, $auma); 

  if ($g_verbose > 0) { print("Searching for neighbors for $aunex...\n"); }

  my @text_elems;
  eval { @text_elems=$root_element->getChildrenByTagName('text'); };
  if($@) {
    if ($g_verbose > 0) { print("$aun_file bears no accepted texts.\n"); }
    next;
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
    if ($g_verbose > 0) { print("Parsing text $text...\n"); }

    if(defined($g_parsed_texts->{'t'}->{$text})) {
      if ($g_verbose > 0) { print("$text already parsed.\n"); }
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
      if ($g_verbose > 0) {  print("Text $text only has one author, skipping $text...\n"); }
      next;
    }
    # Find the collaboration strength by which to increment (the inverse value of) a single edge's weight for this <text/>. 
    $collab_str=1/($k - 1);



    foreach my $name_elem ($text_elem->getChildrenByTagName('hasauthor')) {
      if(not defined($name_elem->getChildrenByTagName('person')->[0])) {
        if ($g_verbose > 0) { print("<hasauthor/> element bears no <person/> element.\n"); }
        next;
      }
      if(not defined($name_elem->getChildrenByTagName('person')->[0]->getChildrenByTagName('name')->[0])) {
        if ($g_verbose > 0) { print("<hasauthor/> element bears no <name/> element.\n"); }
        next;
      }
      $name_elem=$name_elem->getChildrenByTagName('person')->[0]->getChildrenByTagName('name')->[0];
      $status=$name_elem->getAttribute('status');
      if($status == 0) {

        $name=$name_elem->textContent();
        if($name eq $aunex) { next; }
        $name=&decode_utf8($name);
        $name=normalize_name($name);
        
        # Store each aunex that lies 1 binary step away from the author.
        
        if(not defined($aunexes->{'w'}->{$name})) {
          push(@{$aunexes->{'a'}->{$aunex}}, $name);
        }
        $aunexes->{'w'}->{$name}+=$collab_str;
      }
    }
  }

  undef $root_element;
  
  foreach my $aun_2 (keys %{$aunexes->{'w'}}) {
    $aunexes->{'w'}->{$aun_2}=1/($aunexes->{'w'}->{$aun_2});
  }

  # Before returning $aunexes, store its values into the global structure $aunexes.

  my $tot_aun;
  if(defined($aunexes->{'a'}->{$aunex})) {
    $tot_aun=@{$aunexes->{'a'}->{$aunex}};
    if ($g_verbose > 0) { print("Found a total of $tot_aun neighbors for $aunex.\n"); }
  }
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

#  die Dumper $t_gen_progress;

#  my @t_gen_progress=@$p_t_gen_progress;

  my $current_progress=0;

#  for(my $i=0; $i <= scalar $t_gen_progress; $i++) {
  foreach my $explored_depth (keys %{$t_gen_progress}) {
    if($current_progress) { $current_progress*=$t_gen_progress->{$explored_depth}; }
    else { $current_progress=$t_gen_progress->{$explored_depth}; }
  }

#  die $current_progress;

  $current_progress*= 100;

  print "$current_progress", "% finished generating the network tree at a distance of $g_furthest_depth...\n";
#  <STDIN>;

#  exit;

  return $current_progress;
}

sub generate_vema {

  my $edges=shift;

  my $poma=shift;
  my $dist;
  my $r;

  # To give a visualization of the completion of vema exploration.
  my $author_counter=1;
  my $total_authors=scalar(keys %{$edges->{'w'}});


  # For each author in the generated edges...
  foreach my $init_auth (keys %{$edges->{'w'}}) {
    # Check the time limit
    if(($g_init_time - time) >= $g_time_limit) {
      if(not $g_timeout) {
        warn("Time limit of $g_time_limit seconds exceeded by the network exploration - ending the exploration.\n");
        $g_timeout=1;
      }
      last;
    }


    # Start with a distance of 0
    $dist=0;

    $g_furthest_depth=0;

    # Clear the results for vert_go_further_from
    $r=undef;

    # Manually set $r to reflect that the $init_auth is 0 steps from itself.
    $r->{'p'}->{$dist}->{$init_auth}=$init_auth;


    # To give a visualization of the completion of vema exploration.
    if ($g_verbose > 0) { print("Processing author $init_auth...\n"); }
    if ($g_verbose > 0) { print("Author $author_counter of $total_authors.\n"); }

    # The weight of an edge.
    my $weight;

    # To give a visualization of the completion of vema exploration.
    my $aunex_counter=1;

    # THIS IS WHERE THE RECORD TYPE CREATES A PROBLEM

    my $total_aunexes=scalar(keys %{$edges->{'w'}->{$init_auth}});

    my $total_nodes=$total_aunexes;


    #DEBUG
    if(not $total_authors) {
      warn("error in edges structure\n");
      exit;
    }

############################################################3

#    if($total_aunexes > $g_max_nodes) {
#      warn "Too many aunexes at a distance of 1 from $init_auth are being calculated - increase the network exploration breadth.";
#      next;
#    }
    
#    my $current_max_nodes = $g_max_nodes - $total_authors;
#    my $projected_max_nodes;

#    foreach my $init_aun (keys %{$edges->{'w'}->{$init_auth}}) {
#      my $dist_counter=2;
#      while($dist_counter <= $g_maxd) {
#        $projected_max_nodes=+find_total_aunexes_to_dist_for_aunex($init_aun, $dist_counter, $current_max_nodes);
#        if($projected_max_nodes > $current_max_nodes) {
#          print("Maximum exploration breadth breached at $dist_counter\n");
#        }
#        $dist_counter++;
#      }
#    }

#    print "Currently implementing a proper limitation on the breadth of network exploration.\n";

#    exit;

################################################################

    # For each initial aunex for the initial author of the tree...
    foreach my $init_aun (keys %{$edges->{'w'}->{$init_auth}}) {

      # Check the time limit
      if(($g_init_time - time) >= $g_time_limit) {
        if(not $g_timeout) {
          warn("Time limit of $g_time_limit seconds exceeded by the network exploration - ending the exploration.\n");
          $g_timeout=1;
        }
        last;
      }

      # Set the distance to 0.
      $dist=1;

      if($dist > $g_furthest_depth) { $g_furthest_depth = $dist; }

      # To give a visualization of the completion of vema exploration.
      if ($g_verbose > 0) { print("Found primary aunex $init_aun for $init_auth...\n"); }
      if ($g_verbose > 0) { print("Primary aunex $aunex_counter of $total_aunexes for author $author_counter of $total_authors.\n"); }
#      <STDIN>;

      # Manually set $r to reflect that the $init_aun is 1 step from $init_auth.
      $r->{'p'}->{$dist}->{$init_aun}=$init_auth;

      # Unlike with &find_aunexes_for_aun, this structure (produced by &find_aun_for_auth_texts) produced by does yield the Newman-style weights for each edge.
      $weight=$edges->{'w'}->{$init_auth}->{$init_aun};
      
      # Transfer the edge weight to $r from $edges.
      if($weight > 0) { $r->{'w'}->{$init_auth}->{$init_aun}=$weight; }
      
      # If the edge weight passed by $edges <= 0, warn the user and exit the script.
      else {
        warn("WARNING: Could not find edge weight for $init_auth and $init_aun.\n");
        exit;
      }

      # Manually store the vema values at this point.
#      &store_vema_values($init_aun, $init_auth, $dist, $r, $g_vema_db, $g_verbose, $g_vema_db_env);


      &store_vema_values($init_aun, $init_auth, $dist, $r, $g_collec_vema);

      ####################
      
      # DIAGNOSTIC FEATURE - furthest_depth

      ####################

      if(not $g_dry_run) {
       
        if($g_furthest_depth <= $g_maxd and not $g_furthest_depth_explored) {
        
          $g_noma_db=&AuthorProfile::Common::open_db($g_noma_db_file);
          my $noma_record=&AuthorProfile::Common::get_from_db_json($g_noma_db,$init_auth);
          $noma_record->{'furthest_depth'}=$g_furthest_depth;
          #        my $ended_calc_time=time();
          #        $noma_record->{'ended_calculation'}=$ended_calc_time;
          &AuthorProfile::Common::put_in_db_json($g_noma_db,$init_auth,$noma_record);
          &AuthorProfile::Common::close_db($g_noma_db);
          
          $g_noma_db=&AuthorProfile::Common::open_db($g_noma_db_file);
          $noma_record=&AuthorProfile::Common::get_from_db_json($g_noma_db,$init_auth);
          
          if($noma_record->{'furthest_depth'} != $g_furthest_depth or (not exists $noma_record->{'furthest_depth'})) { warn "Corruption in noma database for began_calculation for $init_auth BUT THE CALCULATIONS HAVE BEEN COMPLETED FOR $init_auth to a depth of $g_maxd\n"; }
          
          
          #       if($noma_record->{'ended_calculation'} != $ended_calc_time or (not exists $noma_record->{'ended_calculation'})) { warn "Corruption in noma database for ended_calculation for $sid BUT THE CALCULATIONS HAVE BEEN COMPLETED FOR $sid to a depth of $g_maxd at $ended_calc_time\n"; }
          
          &AuthorProfile::Common::close_db($g_noma_db);
          
          
          undef $noma_record;
          $g_furthest_depth_explored=1;
        }
      }
        
      ####################
      
      # DIAGNOSTIC FEATURE - Tree generation progress

      ####################

      # t_gen_progress array stores the percentage of the tree that has been generated

      # Unique to primary aunexes - declare the t_gen_progress array
      
      # Unique to primary aunexes - store the progress of the primary aunex loop

      my $t_gen_progress;
      
      $t_gen_progress->{$dist}=$aunex_counter/$total_aunexes;

      if(not $g_dry_run) {
        
        $g_noma_db=&AuthorProfile::Common::open_db($g_noma_db_file);
        my $noma_record=&AuthorProfile::Common::get_from_db_json($g_noma_db,$init_auth);
        
        my $current_t_prog=&find_t_gen_progress($t_gen_progress);
        
        $noma_record->{'t_gen_progress'}=$current_t_prog;
        
        &AuthorProfile::Common::put_in_db_json($g_noma_db,$init_auth,$noma_record);
        &AuthorProfile::Common::close_db($g_noma_db);  
        
        $g_noma_db=&AuthorProfile::Common::open_db($g_noma_db_file);
        $noma_record=&AuthorProfile::Common::get_from_db_json($g_noma_db,$init_auth);
        # This addresses a problem with typecasting in Perl
        if(((($current_t_prog - $noma_record->{'t_gen_progress'}) > 0 and ($current_t_prog - $noma_record->{'t_gen_progress'}) > 0.001) or ($current_t_prog - $noma_record->{'t_gen_progress'}) < -0.001) or (not exists $noma_record->{'t_gen_progress'})) {
          die "Corruption in noma database for t_gen_progress for $init_auth";
        }
        
        &AuthorProfile::Common::close_db($g_noma_db);  
        
        
        undef $noma_record;
      }
      
      #####################


      # The neighbors of a given aunex.
      my $neighbors;

      # The previous aunex at this point in the loop is the initial author (distance 0).
      my $old_aunex->{$dist}=$init_auth;
      $old_aunex->{$dist + 1}=$init_aun;
      my $old_inner_counter=undef;
      $old_inner_counter->{$dist}=$author_counter;
      $old_inner_counter->{$dist + 1}=$aunex_counter;
      my $old_n_index=undef;
      $old_n_index->{$dist}=$total_authors;
      $old_n_index->{$dist + 1}=$total_aunexes;

      my $stored_neighbors;

      # The first aunex to explore the neighbors of is the initial aunex (dist 1).
      my $aunex=$init_aun;
      my $i=1;

      # Find the neighbors for the initial aunex.
      $neighbors=&find_aunexes_for_aun($aunex);
      if($neighbors eq 'error') { next; }

      my $probe_dist=$dist + 1;

      if($probe_dist > $g_furthest_depth) { $g_furthest_depth = $probe_dist; }


      $stored_neighbors->{$probe_dist}=$neighbors;

      # Store the number of neighbors found for the initial aunex.
      my $n_i=scalar(keys %{$neighbors->{'w'}});

      if($total_nodes + $n_i > $g_max_nodes) {
        if($g_maxd > 2) {
          $g_maxd--;
          $g_max_nodes_exceeded++;
          warn("Maximum neighbor nodes exceeded at $probe_dist - maximum depth is now $g_maxd.\n");
        }

      }
      else {
        $total_nodes+=$n_i;
      }
      
      # Initialize $dist_2 with a value of 1 (dist 1).
      my $new_neighbors;

############################################################

      # $dist_2 should never be less than 1.  'last' is the only manner by which to exit this loop.

      my $i_2=1;
      my $inner_counter=0;
        
      my $n_index=undef;

      my $aunex_probe=undef;


###################################################################################################

      while($probe_dist > 0) {

        # Check the time limit
        if(($g_init_time - time) >= $g_time_limit) {
          if(not $g_timeout) {
            warn("Time limit of $g_time_limit seconds exceeded by the network exploration - ending the exploration.\n");
            $g_timeout=1;
          }
          last;
        }

        # If $n_aun is undefined within the loop, an error has occurred.
        #DEBUG
        if(not defined($aunex)) {
          warn("\$aunex undefined!");
          if ($g_verbose > 0) { print(Dumper $probe_dist); }
          exit;
        }
        
        # If there are no $neighbors for $n_aun at this point and $dist_2 <= 2, exit the loop.
        # This would mean that the exploration has exhausted all of the aunexes found for the primary aunex at this point.  Hence, the next primary aunex must, then, be explored.
        
        # If $n_aun__2 has been defined, then the inner loop has already run at least once.
        if(defined($aunex_probe)) {

          # 03/05/11 - Avoiding memory leak.
          $r->{'p'}->{$probe_dist}=undef;
          $r->{'w'}->{$aunex}=undef;

          if($probe_dist == ($dist + 1)) { last; }

          $probe_dist--;
          
          $neighbors=$stored_neighbors->{$probe_dist};
          $aunex=$old_aunex->{$probe_dist};
          $n_index=$old_n_index->{$probe_dist};
          $inner_counter=($old_inner_counter->{$probe_dist}) + 1;

          
          while(not defined(($stored_neighbors->{$probe_dist})->{'a'}->{$old_aunex->{$probe_dist}}->[(($old_inner_counter->{$probe_dist}) + 1)])) {

            # 03/05/11 - Avoiding memory leak.
            $r->{'p'}->{$probe_dist}=undef;
            $r->{'w'}->{$aunex}=undef;

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
#            die "here";
            last;
          }
          # DEBUG
#          print Dumper $aunex;
#          print Dumper $neighbors;
          $n_index=scalar(@{$neighbors->{'a'}->{$aunex}});
        }
        
########################################################

        # This loop ends when every aunex held within neighbors has been explored.
        # This ensures that each and every neighbor within a neighborhood is fully explored.
        while($inner_counter < $n_index) {

          # Check the time limit
          if(($g_init_time - time) >= $g_time_limit) {
            if(not $g_timeout) {
              warn("Time limit of $g_time_limit seconds exceeded by the network exploration - ending the exploration.\n");
              $g_timeout=1;
            }
            last;
          }




          # If the maximum distance hasn't been reached, increment the distance (as we are about to go further into the network).

          #For visualization of generation progress.
          my $nnum=$inner_counter + 1;
          my $ntot=$n_index;

          # $n_aun__2 is now the neighbor corresponding to the index $i_3 within the neighborhood stored by $neighbors.
          $aunex_probe=$neighbors->{'a'}->{$aunex}->[$inner_counter];



          if ($g_verbose > 0) { print("generate_vema: Probing $aunex_probe \(neighbor $nnum of $ntot\) for $aunex at distance $probe_dist from $init_aun \($aunex_counter of $total_aunexes\) from $init_auth \($author_counter of $total_authors\).\n"); }

          # Construct the vema path for $n_aun__2 and store it in the vema database.
          $r=&vert_go_further_from($init_auth, $aunex, $vema, $r, $probe_dist, $aunex_probe, $neighbors, $poma);

          ####################
      
          # DIAGNOSTIC FEATURE - furthest_depth
          
          ####################
          
          if(not $g_dry_run) {
            
            if($g_furthest_depth <= $g_maxd and not $g_furthest_depth_explored) {
              
              $g_noma_db=&AuthorProfile::Common::open_db($g_noma_db_file);
              my $noma_record=&AuthorProfile::Common::get_from_db_json($g_noma_db,$init_auth);
              $noma_record->{'furthest_depth'}=$g_furthest_depth;
              #        my $ended_calc_time=time();
              #        $noma_record->{'ended_calculation'}=$ended_calc_time;
              &AuthorProfile::Common::put_in_db_json($g_noma_db,$init_auth,$noma_record);
              &AuthorProfile::Common::close_db($g_noma_db);
              
              $g_noma_db=&AuthorProfile::Common::open_db($g_noma_db_file);
              $noma_record=&AuthorProfile::Common::get_from_db_json($g_noma_db,$init_auth);
              
              if(($noma_record->{'furthest_depth'} != $g_furthest_depth) or (not exists $noma_record->{'furthest_depth'})) { warn "Corruption in noma database for began_calculation for $init_auth BUT THE CALCULATIONS HAVE BEEN COMPLETED FOR $init_auth to a depth of $g_furthest_depth\n"; }
              
              
              #       if($noma_record->{'ended_calculation'} != $ended_calc_time or (not exists $noma_record->{'ended_calculation'})) { warn "Corruption in noma database for ended_calculation for $sid BUT THE CALCULATIONS HAVE BEEN COMPLETED FOR $sid to a depth of $g_maxd at $ended_calc_time\n"; }
              
              &AuthorProfile::Common::close_db($g_noma_db);
              
              
              undef $noma_record;
              $g_furthest_depth_explored=1;
            }
          }
        
          ####################

          # DIAGNOSTIC FEATURE - Tree generation progress

          ####################

          # t_gen_progress array stores the percentage of the tree that has been generated
          
          # Unique to secondary aunexes - store the progress of the primary aunex loop
          
#          $t_gen_progress->{$probe_dist}=$nnum/$ntot;

          my $null_var=0;
          
          if($null_var) {
#          if(not $g_dry_run) {
            
            $g_noma_db=&AuthorProfile::Common::open_db($g_noma_db_file);
            my $noma_record=&AuthorProfile::Common::get_from_db_json($g_noma_db,$init_auth);
            
            my $current_t_prog=&find_t_gen_progress($t_gen_progress);
            
            $noma_record->{'t_gen_progress'}=$current_t_prog;
            
            &AuthorProfile::Common::put_in_db_json($g_noma_db,$init_auth,$noma_record);
            &AuthorProfile::Common::close_db($g_noma_db);  
            
            $g_noma_db=&AuthorProfile::Common::open_db($g_noma_db_file);
            $noma_record=&AuthorProfile::Common::get_from_db_json($g_noma_db,$init_auth);
            
            if(((($current_t_prog - $noma_record->{'t_gen_progress'}) > 0 and ($current_t_prog - $noma_record->{'t_gen_progress'}) > 0.001) or ($current_t_prog - $noma_record->{'t_gen_progress'}) < -0.001) or (not exists $noma_record->{'t_gen_progress'})) {
              print Dumper ($current_t_prog - $noma_record->{'t_gen_progress'});
              die "Corruption in noma database for t_gen_progress for $init_auth";
            }
            
            &AuthorProfile::Common::put_in_db_json($g_noma_db,$init_auth,$noma_record);
            &AuthorProfile::Common::close_db($g_noma_db);  
            
            
            undef $noma_record;
          }
          
          #####################


          # Continue exploring further if the maximum distance has yet to be reached.
          if($probe_dist < $g_maxd) {

            # Check the time limit
            if(($g_init_time - time) >= $g_time_limit) {
              if(not $g_timeout) {
                warn("Time limit of $g_time_limit seconds exceeded by the network exploration - ending the exploration.\n");
                $g_timeout=1;
              }
              last;
            }

            # ...set the structure $new_neighbors to the $neighbors of the current secondary aunex...
            $new_neighbors=&find_aunexes_for_aun($aunex_probe);
            if($new_neighbors eq 'error') { next; }

            # Check to see if $n_aun__2 is an isolated aunex.
            if(not keys %{$new_neighbors->{'w'}}) {
              # If so, move to the next secondary aunex that isn't isolated.

              if ($g_verbose > 0) { print("generate_vema: Skipping isolated neighbor $aunex_probe...\n"); }
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

            if($probe_dist > $g_furthest_depth) { $g_furthest_depth = $probe_dist; }

            if ($g_verbose > 0) { print("generate_vema: Exploring the neighbors for $aunex_probe...\n"); }

            # Set the neighbors to the newly found neighbors for the loop.
            $neighbors=$new_neighbors;
            $new_neighbors=undef;

            # Set the predecessor aunex to the current aunex used for exploration.
            $aunex=$aunex_probe;

            #DEBUG
            if(not defined($aunex)) {
              print("ERROR: \$aunex not defined.\n");
              exit;
            }
            #END DEBUG

            # Set the new neighborhood index.
            $n_index=scalar(@{$neighbors->{'a'}->{$aunex}});

            if($total_nodes + $n_index > $g_max_nodes) {
              if($g_maxd > 2) {
                $g_maxd--;
                $g_max_nodes_exceeded++;
              }

              warn("Maximum neighbor nodes exceeded at $probe_dist - maximum node depth set to $g_maxd.\n");
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

        if ($g_verbose > 0) { print("The inner loop has finished for the exploration of neighbors lying one step away from $aunex \(which is a distance of $probe_dist from $init_auth\).\n"); }
        next;
      }
#####################################################################
      if ($g_verbose > 0) { print("Finished exploring all neighbors for $init_aun\n"); }
      $aunex_counter++;
      next;
    }
#####################################################################
    if ($g_verbose > 0) { print("Finished exploring all aunexes for author $init_auth.\n"); }
    $author_counter++;
    next;
  }
#####################################################################
  return $vema;
}

sub create_noma_db {

  my $noma_db_file=shift;

  

  # Construct the BerkDB ENV
  
  # Close the old database
  $g_noma_db->db_close;

  # Close the old database environment
#  $g_vema_db_env->close;

#  print $vema_db_file;

  #ENV DISABLED
#  my $vema_db_dir=$vema_db_file;

#  $vema_db_dir=~s|^\.\.||;
#  $vema_db_dir=~s|^\.||;
#  $vema_db_dir=~s|[a-zA-Z0-9\.]*$||;
#  $vema_db_dir=~s|/$||;

#  $vema_db_file=~s|^$vema_db_dir||;

#  $g_vema_db_env = new BerkeleyDB::Env
#    -Home   => $vema_db_dir,
#      -Flags  => DB_CREATE| DB_INIT_CDB | DB_INIT_MPOOL
#        or die "cannot open database: $BerkeleyDB::Error\n";
  
  # Construct the handler-object for the BerkDB that stores the $vema values
  $g_noma_db = new BerkeleyDB::Hash
    -Filename => $noma_db_file,
      -Flags    => DB_CREATE
#        -Env      => $g_vema_db_env
          or die "cannot open database: $BerkeleyDB::Error\n";

  return 0;
}


sub create_vema_db {

  my $vema_db_file=shift;

  

  # Construct the BerkDB ENV
  
  # Close the old database
  $g_vema_db->db_close;

  # Close the old database environment
#  $g_vema_db_env->close;

#  print $vema_db_file;

  #ENV DISABLED
#  my $vema_db_dir=$vema_db_file;

#  $vema_db_dir=~s|^\.\.||;
#  $vema_db_dir=~s|^\.||;
#  $vema_db_dir=~s|[a-zA-Z0-9\.]*$||;
#  $vema_db_dir=~s|/$||;

#  $vema_db_file=~s|^$vema_db_dir||;

#  $g_vema_db_env = new BerkeleyDB::Env
#    -Home   => $vema_db_dir,
#      -Flags  => DB_CREATE| DB_INIT_CDB | DB_INIT_MPOOL
#        or die "cannot open database: $BerkeleyDB::Error\n";
  
  # Construct the handler-object for the BerkDB that stores the $vema values
  $g_vema_db = new BerkeleyDB::Hash
    -Filename => $vema_db_file,
      -Flags    => DB_CREATE
#        -Env      => $g_vema_db_env
          or die "cannot open database: $BerkeleyDB::Error\n";

  return 0;
}

sub proc_args {

  my $input_var=shift;

##################################
# Exact string comparisons
##################################

  # Deprecated: This is a default setting.
#  if($input_var eq '--no-edges') {
#    $g_store_edges=0;
#    return;
#  }

  if($input_var eq '--store-edges') {
    $g_store_edges=1;
    return;
  }

  if($input_var eq '--forced-auma-regen') {
    $g_force_auma_regen=1;
    return;
  }
  if($input_var eq '-q' or $input_var eq '--quiet') {
    $g_verbose=0;
    return;
  }
  if($input_var eq '--dry-run') {
    $g_dry_run=1;
    return;
  }
  if($input_var eq '--width-priority') {
    $g_width_p=1;
    return;
  }

##################################
# Regexp operations
##################################

  if($input_var=~m|--vertical-database=|) {
    my $vema_db_file=$input_var;
    $vema_db_file=~s|--vertical-database=||;
    if(not -f $vema_db_file) {
      $vema_db_file=~s|^~|$home_dir|;
      if(not -f $vema_db_file) {
        warn("File $vema_db_file doesn't exist!\n");
        return;
      }
    }
    if($g_verbose) { print "Vertical database file set to $vema_db_file\n"; }
    &create_vema_db($vema_db_file);
    return;
  }

  if($input_var=~m|--diagnostics-database=|) {
    my $noma_db_file=$input_var;
    $noma_db_file=~s|--diagnostics-database=||;
    if(not -f $noma_db_file) {
      $noma_db_file=~s|^~|$home_dir|;
      if(not -f $noma_db_file) {
        warn("File $noma_db_file doesn't exist!\n");
        return;
      }
    }
    if($g_verbose) { print "Diagnostics database file set to $noma_db_file\n"; }
    &create_noma_db($noma_db_file);
    return;
  }

  if($input_var=~m|--maxd=|) {
    my $maxd=$input_var;
    $maxd=~s|--maxd=||;
    if(not $maxd) {
      warn("No maximum distance passed!\n");
      return;
    }
    $g_maxd=$maxd;
    return;
  }
  if($input_var=~m|-d|) {
    my $maxd=$input_var;
    $maxd=~s|-d||;
    if(not $maxd) {
      warn("No maximum distance passed!\n");
      return;
    }
    if($g_verbose) { print "Maximum distance set to $maxd\n"; }
    $g_maxd=$maxd;
    return;
  }
  if($input_var=~m|-n|) {
    my $maxn=$input_var;
    $maxn=~s|-n||;
    if(not $maxn) {
      warn("No maximum distance passed!\n");
      return;
    }
    if($g_verbose) { print "Node limit set to $maxn nodes\n"; }
    $g_max_nodes=$maxn;
    return;
  }
  if($input_var=~m|--time-limit=|) {
    my $maxt=$input_var;
    $maxt=~s|--time-limit=||;
    if(not $maxt) {
      warn("No time limit passed!\n");
      return;
    }
    if($g_verbose) { print "Time limit set to $maxt seconds\n"; }
    $g_time_limit=$maxt;
    return;
  }
  if($input_var=~m|-t|) {
    my $maxt=$input_var;
    $maxt=~s|-t||;
    if(not $maxt) {
      warn("No time limit passed!\n");
      return;
    }
    if($g_verbose) { print "Time limit set to $maxt seconds\n"; }
    $g_time_limit=$maxt;
    return;
  }

##################################

  warn("Unrecognized argument '$input_var' passed - ignoring this!\n");
  return;
}

sub proc_input {
  foreach my $input_var (@ARGV) {
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

#####################################################

# The Main function of the script


sub main {

  &proc_input();

  &init_auma();

  &init_edges();

  if(not $g_input) {

    # If there is no file supplied, parse the record for Thomas Krichel:
    $g_input="$ap_dir/k/r/pkr1.amf.xml";

    print("No file\(s\) passed, processing $g_input...\n") if $g_verbose;

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
#  print("vert_go_further_from invoked.\n");

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
  my $verbosity=$g_verbose;
  my $dry_run=$g_dry_run;

  my $w=0;
  my $i=1;

  my $n_i=scalar(keys %{$neighbors->{'w'}});
  my $vema=undef;

  $vema=undef;

  my $vema_key=normalize_name($n_aun);

  $vema=&vema_db_retrieve($vema_key, $g_collec_vema);

  if(not $n_aun) {
    warn("vert_go_further_from: FATAL ERROR: \$n_aun not passed.\n");
    exit;
  }

  if(not $r or not defined($r->{'p'}->{$dist}->{$n_aun})) {
    #This is still needed to construct the vema path...
    $r->{'p'}->{$dist}->{$n_aun}=$i_aun;
  }
  
  # The weight for the neighbors structure was not stored as a symmetric weight value, but instead, as simply the summation of the total amount of collaborating authors for each paper collaborated upon by the authors to whom the aunexes being compared belong.  I am not sure what my reasoning behind this was at the time, but it may be unnecessary.

  $w=$neighbors->{'w'}->{$n_aun};

  if($w > 0) { $r->{'w'}->{$i_aun}->{$n_aun}=$w; }
  else {
    warn("vert_go_further_from: FATAL ERROR: Edge weight for $i_aun and $n_aun could not be found.\n");
    print(Dumper $neighbors);
    exit;
  }

  # If a vema path has already been stored into the database...
  if(defined($vema)) {
    # ...first check to see if the stored path is of a greater length that the path just generated for the aunex being explored...
    if($vema->{'d'} > $dist)
      {
        if($verbosity > 0) { print "vert_go_further_from: Shorter path found for $n_aun from $i_aun.\n"; }
      # ...and store the newly calculated path if it is indeed shorter.
#      if(not $dry_run) { &store_vema_values($n_aun, $init_auth, $dist, $r, $g_vema_db, $g_verbose,$g_vema_db_env); }

      if(not $dry_run) { &store_vema_values($n_aun, $init_auth, $dist, $r, $g_collec_vema); }

    }
    # ...otherwise, if the length of the vema path is equal to the path that has been stored...
    elsif($vema->{'d'} == $dist) {
      # ...and if the weight is less than the stored path...
      if($vema->{'w'} > $r->{'w'}->{$i_aun}->{$n_aun}) {
        #...store the newly calculated vema path.
        if($verbosity > 0) { print("vert_go_further_from: Lighter path found for $n_aun from $i_aun.\n"); }
#        if(not $dry_run) { &store_vema_values($n_aun, $init_auth, $dist, $r, $g_vema_db, $g_verbose,$g_vema_db_env); }

        if(not $dry_run) { &store_vema_values($n_aun, $init_auth, $dist, $r, $g_collec_vema); }

      }
      # ...or, if the distance is the same but the weight of the newly calculated path is greater than the stored vema path, compare, then, use the poma for a conmparison...
      elsif($vema->{'e'} ne $init_auth and &compare_nodes_using_poma($vema->{'e'}, $init_auth, $poma) eq $init_auth) {
        # and if the preferred author is the initial node of this path, store the newly calculated vema path.
        if($verbosity > 0) { print("vert_go_further_from: The poma prefers path found for $n_aun from $i_aun to the path stored in the vema database.\n"); }
#        if(not $dry_run) { &store_vema_values($n_aun, $init_auth, $dist, $r, $g_vema_db, $g_verbose,$g_vema_db_env); }

        if(not $dry_run) { &store_vema_values($n_aun, $init_auth, $dist, $r, $g_collec_vema); }

      }
    }
  }
  # ...and if the path hasn't been stored into the vema database at all, store the path.
  else {
    if($verbosity > 0) { print("vert_go_further_from: New path found for $n_aun from $i_aun.\n"); }
#    if(not $dry_run) { &store_vema_values($n_aun, $init_auth, $dist, $r, $g_vema_db, $g_verbose,$g_vema_db_env); }

    if(not $dry_run) { &store_vema_values($n_aun, $init_auth, $dist, $r, $g_collec_vema); }

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
__END__
