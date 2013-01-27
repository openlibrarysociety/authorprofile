package AuthorProfile::Network;

=head1 NAME

AuthorProfile::Network

=cut

use strict;
use warnings;
use lib qw( /home/aupro/ap/perl/lib /home/aupro/usr/lib/perl );
use Carp::Assert;
use Date::Format;
use Data::Dumper;
use AuthorProfile::Common qw( get_aunexes_per_docid
                              put_in_db_json
                              put_in_mongodb
                              get_from_mongodb
                              get_mongodb_collection
                              get_root_from_file
                              json_store
                              updateMongoDBRecord
                           );
use AuthorProfile::Conf;
use AuthorProfile::Auvert qw(normalize_name);
use JSON::XS;

use BerkeleyDB;

use XML::LibXML;
use List::Util qw(shuffle);
use File::Temp qw/ tempfile tempdir /;
use File::Compare;
use File::Copy;

our @ISA = qw(Exporter);

our @EXPORT_OK = qw( go_further_from
                     compare_nodes_using_poma
                     find_edges
                     weighted_network_edges
                     vema_db_retrieve
                     noma_db_retrieve
                     insert_vert_data_xml
                     store_vema_values
                     update_noma_values
                     compare_nodes_using_poma_vert
                     generate_poma
                     insert_horizontal_xml
                  );

use utf8;

# 01/23/12 - James
# LibXML::Document insert_horizontal_xml(SCALAR LibXML::Document, SCALAR aunex, SCALAR REFERENCE errors)
# This retrieves the horizontal integration data for a given aunex from the MongoDB
# Please note that horizontal integration records do NOT store normalized aunexes, as the normalized string cannot be restored to the original string.
# The XML Element is structured in the following manner:
# <ap:horizontal aunex="AUNEX">
#     <ap:horizontalNode>AUNEX_1</ap:horizontalNode>
#     <ap:horizontalNode>AUNEX_2</ap:horizontalNode>
#     [...]
#     <ap:horizontalNode>AUNEX_N</ap:horizontalNode>
# </ap:horizontal>

sub insert_horizontal_xml {

  my($amf_doc,$aunex,$errors) = @_;
  my $collec=AuthorProfile::Common::get_mongodb_collection('horizontal');
  my @records=AuthorProfile::Common::get_from_mongodb($collec,{'aunex' => $aunex});
  my $record=pop @records;
  if(not $record) {
    $$errors.='Could find no horizontal integration records for'.$aunex;
    $$errors.=Dumper AuthorProfile::Common::get_from_mongodb($collec,{'aunex' => $aunex});
    return $amf_doc;
  }

  if(not $record->{'lastUpdateSuccessful'}) {
    return $amf_doc;
  }

  my $horizontal_element=$amf_doc->createElementNS($ap_ns, 'ap:horizontal');
  my $root_element=eval{$amf_doc->documentElement()};
  if($@) {
    $amf_doc->setDocumentElement($horizontal_element);
    $root_element=$amf_doc->documentElement();
  }
  $root_element->appendChild($horizontal_element);
  # lastUpdateSuccessful
  # timeLastUpdated
  
  $horizontal_element->setAttribute('aunex', $aunex);
  foreach my $horizontal_node (@{$record->{'horizontalNodes'}}) {
    next if $horizontal_node eq $aunex;
    my $horiz_node_elem=eval{$horizontal_element->addNewChild($ap_ns, 'horizontalAunex')};
    next if $@;
    $horiz_node_elem->appendText($horizontal_node);
  }

  my $timeLastUpdated=$record->{'timeLastUpdated'};
  $horizontal_element->setAttribute('performance', "The horizontal integration calculations last finished for the aunex \x{201C}".$aunex."\x{201D} at ".time2str("%c %Z",$timeLastUpdated)) if $timeLastUpdated;
  
  return $amf_doc;
}

sub insert_vert_data_xml {

  my($doc,$norm_name,$errors,$debug)=@_;

  my $root_element=$doc->documentElement();

  my $vema_db_values;

  my $collec=AuthorProfile::Common::get_mongodb_collection('vema');
  my @records=AuthorProfile::Common::get_from_mongodb($collec,{'aunex' => $norm_name});
  $vema_db_values=pop @records;
  if(not $vema_db_values) {
    $$errors.="empty vema values returned!";
    return $doc;
  }

  my $vert_element=$doc->createElementNS($ap_ns, 'ap:vertical');

  if(not $root_element) {
    $doc->setDocumentElement($vert_element);
    $root_element=$doc->documentElement();
  }
  else { 
    $root_element->appendChild($vert_element); 
  }

  $vert_element->setAttribute('length', $vema_db_values->{'d'});
  my $sid=$vema_db_values->{'e'};
  $vert_element->setAttribute('author', $sid);

  my $auth_name=retrieve_name_for_sid($sid);

  if($auth_name) {

    $vert_element->setAttribute('name',$auth_name);

    # 01/24/12 - James
    $collec=AuthorProfile::Common::get_mongodb_collection('noma');
    @records=AuthorProfile::Common::get_from_mongodb($collec,{'author' => $sid});
    my $noma_db_values=pop @records;
    if($noma_db_values->{'ended_calculation'} < $noma_db_values->{'began_calculation'}) {
      $vert_element->setAttribute('performance','Warning: The vertical integration calculations have not finished for '.$auth_name.'.  One may find inconsistent network paths or may not find expected network paths.');
    }
    else {
      $vert_element->setAttribute('performance','The vertical integration calculations last finished for '.$auth_name.' at '.time2str("%c %Z",$noma_db_values->{'ended_calculation'}.'.'));
    }
  }

  my $path=$vema_db_values->{'p'};        
  $vert_element=&add_vert_elem($path, $vert_element, $doc);

  return $doc;
}

sub add_vert_elem {
  my $path=shift;
  my $vert_element=shift;
  my @p_auth=split(/_/, $path);

  my $p_auth_ind=($#p_auth - 1);
  my $aun_elem;
  while($p_auth_ind >= 0) {
    $aun_elem=$vert_element->addNewChild($ap_ns, 'aunex');
    $aun_elem->setAttribute('name', $p_auth[$p_auth_ind]);    
    $p_auth_ind--;
  }
  return $vert_element;
}

# This function stores each value of the $vema structure's for each specific author (here, the $vema_key) into a Berkeley database. This database is currently stored in ~/var/vertical/vema.db.

# One possible problem here is where, precisely, the BerkeleyDB object should be initialized and constructed:
# Should the object (whose reference is held by $vema_db within the scope of this function) be declared only within the invoking script file (in this case, vertical.pl)?  Or, rather, should it be declared within this module and its reference made globally accessible by whatever script is invoking those functions which require transactions with the BerkDB object? (Specifically, in this case, Web.pm, which shall need to, at some point, access the vertical integration data stored within vema.db).

sub noma_db_retrieve {

  my $author_key=shift;
  my $collec=shift;

  my @objs;
  eval {
    @objs=AuthorProfile::Common::get_from_mongodb($collec,{'author' => $author_key});
  };
  if($@) {
    die "Fatal Error: Could not retrieve record for $author_key from authorprofile.noma";
  }

  return $collec;
}

sub vema_db_retrieve {
  my $aunex_key=shift;
  my $collec=shift;
  my $errors=shift;

  my @objs;

  my $new_coll = MongoDB::Connection->new->get_database('authorprofile')->get_collection('vema') or die "FATAL ERROR: Could not connected to MongoDB authorprofile.vema - $!";

  eval {
    @objs=AuthorProfile::Common::get_from_mongodb($new_coll, {'aunex' => $aunex_key});
  };

  my $record=pop @objs;

  if($@ or not $record) {
    warn "Warning: Could not retrieve record for $aunex_key in MongoDB collection $collec";
    warn $! if $@;
    warn "\n";
    return undef;
  }

  return $record;
}


# This function performs the essential task of storing the actual calculated paths into the $vema structure.  It depends upon the following two functions in order to properly store calculated values into the $vema:

# &find_vema_w
# &vema_db_store

sub find_vema_w {

  my $vema=shift;
  my $vema_path=shift;
  my $dest_aun=shift;
  my $n_pre=shift;
  my $dist=shift;

  if(not defined($vema_path)) { return $vema; }
  my @path=split(/_/, $vema_path);

  my $node_1;
  my $node_2;

  my $edge;

  my $i=0;

  while($i < $#path) {
    if(not ($path[$#path])) {
      warn("WARNING: Empty path node found for $dest_aun in \$vema structure.\n");

      return $vema;
    }
    $node_1=$path[(($#path - $i) - 1)];
    $node_2=$path[$#path - $i];

    $edge=$n_pre->{'w'}->{$node_2}->{$node_1};

    if(not defined($node_1) or not defined($node_2)) { next; }
    if(not defined($edge)) {
      warn "Warning: No edge weight found for $node_2 and $node_1.\n";
      $i++;
      next;
    }
#    print("Incrementing the path weight by the weight of edge between nodes ", $node_2, ' and ', $node_1, ".\n");
#    print 'Edge Weight: ',$edge, "\n";
    if(defined($vema->{$dest_aun}->{'w'})) {
#      print("\$vema weight before the incrementation: ", $vema->{$dest_aun}->{'w'}, "\n");
    }
    
    $vema->{$dest_aun}->{'w'}+=$edge;
    if($vema->{$dest_aun}->{'w'} > 1) {
      $vema->{$dest_aun}->{'w'}=1/$vema->{$dest_aun}->{'w'};
    }
#    print("\$vema weight after the incrementation: ", $vema->{$dest_aun}->{'w'}, "\n");
    
    $i++;
  }
#  print "\$vema weight after the loop: ",$vema->{$dest_aun}->{'w'},"\n";
#  <STDIN>;

  return $vema;
}

sub vema_db_store_old {
  my $vema_values=shift;
  my $vema_db=shift;
  my $vema_key=shift;

  &put_in_db_json($vema_db, $vema_key, $vema_values);
  print("vema path stored into vema database.\n\n");

  return 0;
}

sub vema_db_store {
  my $collec=shift;
  my $vema_record=shift;
#  my $vema_db=shift;
  my $aunex=shift;

#  &put_in_db_json($vema_db, $vema_key, $vema_values);
  $vema_record->{'aunex'}=$aunex;

  $vema_record->{'timeLastUpdated'}=time;
  $vema_record->{'lastUpdateSuccessful'}=1;
  # return AuthorProfile::Common::updateMongoDBRecord('authorprofile','auversion',$_[0],$_[1],{"upsert" => 1,"multiple" => 0,"safe" => 1}) or die "Fatal: Could not update the auversion record for $_[0]: $!";
  AuthorProfile::Common::updateMongoDBRecord('authorprofile','vema',{'aunex'=>$aunex},{'$set'=>$vema_record},{'upsert'=>1,'multiple'=>0,'safe'=>1});
  return 0;
}

# Move this to Common.pm

sub verify_transaction_mongodb {

  my $collec=shift;
  my $record=shift;

  # Needed? (Unsure)...
  my @keys=shift;
  my @values=shift;

  # Form the query...

  my $query={};
  
  my $i=0;
  foreach my $key (@keys) {
    $query->{$key}=$values[$i];
    $i++;
  }

  my $results;
  my @records;

  @records=AuthorProfile::Common::get_from_mongodb($collec,$query);
  if(not @records) {
    die "Fatal Error: Failed to retrieve records for the verification of the previous transaction in the database:\n",Dumper $collec;
  }

  my $found_record=pop @records;

  foreach my $record_key (keys %{$record}) {
    if($found_record->{$record_key} ne $record->{$record_key}) {
      die "Fatal Error: Failed to verify the previous transaction in the database:\n",Dumper $collec,Dumper $record,Dumper $found_record;
    }
  }

  return 0;
}


sub update_noma_values {
  my $author_key=shift;
  my $collec=shift;
  my @keys=shift;
  my @values=shift;

  my @noma_records;
  my $noma_db_values;

  my $key;
  my $value;

  @noma_records=AuthorProfile::Common::get_from_mongodb($collec,{'author' => $author_key});
  if(not @noma_records) {
    die "Fatal Error: Attempted to perform VIC for $author_key without a record in authorprofile.noma";
  }
  my $noma_record=pop @noma_records;



  if(not exists $noma_record->{'last_change_date'}) {
    die "Fatal Error: Attempted to perform VIC for $author_key without a value in 'last_change_date'";
  }

  my $i=0;
  foreach my $key (@keys) {
    $noma_record->{$key}=$values[$i];
    $i++;
  }

#  print Dumper scalar @keys;
#  print Dumper @keys;

#  for(my $i=0; $i <= $#keys; $i++) {
#    $noma_record->{$keys[$i]}=$values[$i];
#  }
#  print ref \@keys;
#  print Dumper scalar \@keys;
#  print Dumper ref \@keys;
#  print Dumper @keys;
  #print Dumper $noma_record;
  #<STDIN>;

  my $results;

  eval { $results=AuthorProfile::Common::put_in_mongodb($collec,$noma_record,'author'); };
  if($@) {
    die "Fatal Error: Could not update $value to $key for $author_key";
  }

  # Confirm that the transaction has been performed properly...
  return verify_transaction_mongodb($collec,$noma_record,'author',$author_key);

#  die $results;

# $noma->{[SID]}->{'last_change_date'}
# $noma->{[SID]}->{'began_calculation'}
# $noma->{[SID]}->{'ended_calculation'}
# $noma->{[SID]}->{'furthest_depth'}

#  eval {
#    $collec->update({'author' => $author_key},
#                    {$key     => $value});
#  };
#  if($@) {
#    die "Fatal Error: Could not update $value to $key for $author_key";
#  }
#  return 1;
}

sub store_vema_values {

  my $dest_aun=shift;
  my $init_auth=shift;
  my $dist=shift;
  my $n_pre=shift;
  my $collec=shift;

  my $VERBOSE=1;

  # The vema structure is constructed within this function.
  my $vema=undef;

  my $vema_key=normalize_name($dest_aun);

  $vema->{$vema_key}->{'d'}=$dist;
  $vema->{$vema_key}->{'e'}=$init_auth;

  # ...then, by placing the neighbor author as the initial node of the path...
  $vema->{$vema_key}->{'p'}=$dest_aun;

  my $i_dist=$dist;
  my $j_aun=$dest_aun;
  my $pre_aun;

  # ...followed by concatenating an '_' and the 'predecessor author' for each binary step from the neighbor author.
  while($i_dist > 0) {
    # This should NOT occur!
    if(not defined($n_pre->{'p'}->{$i_dist}->{$j_aun})) {
      warn("FATAL ERROR: n_pre not passed properly\n");
      warn(Dumper $n_pre->{'p'}->{$i_dist});
      warn("Dist: $i_dist\n");
      warn($j_aun);
      exit;
    }
    $pre_aun=$n_pre->{'p'}->{$i_dist}->{$j_aun};
#    print("At distance $i_dist, $j_aun predecessor is $pre_aun.\n"); 
    $vema->{$vema_key}->{'p'}.= ('_' . $n_pre->{'p'}->{$i_dist}->{$j_aun});
    $j_aun=$n_pre->{'p'}->{$i_dist}->{$j_aun};
    $i_dist--;
  }



  $vema=&find_vema_w($vema, $vema->{$vema_key}->{'p'}, $vema_key, $n_pre, $dist);

  print "vema path generated for $dest_aun, $dist steps from $init_auth\nStoring path into vema database...\n" if $VERBOSE;
  print Dumper $vema;


  &vema_db_store($collec,$vema->{$vema_key},$vema_key);
  $vema=undef;

  return 0;
}



# This version has been adjusted specifically for performing the vertical integration calculations

sub compare_nodes_using_poma_vert {
  my $a=shift;
  my $b=shift;
  my $poma=shift;
  assert($a);
  assert($b);
  assert($poma);
  ## first, deal with the more likely case whore
  ## $a and $b are in the same component
  if($poma->{'components'}->{$a} == $poma->{'components'}->{$b}) {
    #print "$a and $b are in component $components->{'components'}->{$b}\n";
    ## if $a has larger centrality
    if($poma->{'centralities'}->{$a}>$poma->{'centralities'}->{$b}) {
      return $a;
    }
    ## if $b has larger centrality
    if($poma->{'centralities'}->{$b}>$poma->{'centralities'}->{$a}) {
      return $b;
    }
    ## case of equal centrality, same component, use power->{'common'}
    ## if $a has larger power->{'common'}
    if($poma->{'power'}->{'common'}->{$a}>$poma->{'power'}->{'common'}->{$b}) {
      return $a;
    }
    ## if $b has larger power->{'common'}
    if($poma->{'power'}->{'common'}->{$b}>$poma->{'power'}->{'common'}->{$a}) {
      return $b;
    }
    ## case of equal centrality, same component, use power->{'size'}
    ## if $a has larger power->{'size'}
    if($poma->{'power'}->{'size'}->{$a}>$poma->{'power'}->{'size'}->{$b}) {
      return $a;
    }
    ## if $b has larger power->{'size'}
    if($poma->{'power'}->{'size'}->{$b}>$poma->{'power'}->{'size'}->{$a}) {
      return $b;
    }
    ## this should not happen, but it may
    warn "poma can not distinguish $a from $b, common component\n";
    return $a;
  }
  ## $a and $b are in the different component, prefer larger component, first by members
  my $a_size=scalar keys %{$poma->{'components'}->{$poma->{'components'}->{$a}}};
  my $b_size=scalar keys %{$poma->{'components'}->{$poma->{'components'}->{$b}}};
  if($a_size>$b_size) {
    return $a;
  }
  if($b_size>$a_size) {
    return $b;
  }
  ## $a and $b are in the different component, prefer larger component, second by papers written by members
  $a_size=$poma->{'components'}->{$poma->{'components'}->{$a}}->{'size'};
  $b_size=$poma->{'components'}->{$poma->{'components'}->{$b}}->{'size'};
  if($a_size>$b_size) {
    return $a;
  }
  if($b_size>$a_size) {
    return $b;
  }
  ## case of equal component size, prefer larger power
  ## if $a has larger power->{'common'}
  if($poma->{'power'}->{'common'}->{$a}>$poma->{'power'}->{'common'}->{$b}) {
    return $a;
  }
  ## if $b has larger power->{'common'}
  if($poma->{'power'}->{'common'}->{$b}>$poma->{'power'}->{'common'}->{$a}) {
    return $b;
  }
  ## case of equal centrality, same component, use power->{'size'}
  ## if $a has larger power->{'size'}
  if($poma->{'power'}->{'size'}->{$a}>$poma->{'power'}->{'size'}->{$b}) {
    return $a;
  }
  ## if $b has larger power->{'size'}
  if($poma->{'power'}->{'size'}->{$b}>$poma->{'power'}->{'size'}->{$a}) {
    return $b;
  }  
  ## if $a has larger power
  ## this should not happen, but it may
  warn "poma can not distinguish $a from $b, different component size $a_size\n";
  return $a;
}

## moves one step ahead in a network
## function used in compose_poma, don't change
sub go_further_from {
  # starting author
  my $a=shift;
  my $r=shift;
  my $d_count=shift;
  my $edges=shift;
  # return value
  #print Dumper $r;
  foreach my $n (keys %{$edges->{$a}}) {
    #print "n is '$n'\n";
    if(not defined($r->{'d'}->{$n})) {
      $r->{'d'}->{$n}=$d_count;
      push(@{$r->{'p'}->{$n}},$a);
    }
    elsif($r->{'d'}->{$n} == $d_count) {
      push(@{$r->{'p'}->{$n}},$a);
    }
  }
  return $r;
}


## moves one step ahead in a network
sub go_further_from_james {
#  print("Using network function...\n");
#  exit;
  # starting author
  my $a=$_[0];
  my $r=$_[1];
  my $d_count=$_[2];
  my $edge=$_[3];
  my $vema=$_[4];
  my $poma=$_[5];
  # return value
  foreach my $n (keys %{$edge->{$a}}) {
    #print "n is '$n'\n";
    if(not defined($r->{d}->{$n})) {
      $r->{d}->{$n}=$d_count;
    }
    if(not defined($r->{p}->{$n})) {
      $r->{p}->{$n}=$a;
    }
    # go_further_from is used when composing the poma. It can not depend on it.
    # First, check to see if the $poma has been properly passed...
    if(not defined($poma) or ref($poma) ne 'HASH') {
      # ...if it hasn't, then there isn't much purpose in performing operations concerning the $vema.
      warn("Error: Value of \$poma passed to go_further_from undefined.\n");
      next;
    }
    # ...if it has, then proceed by...
    elsif(ref($vema) eq 'HASH' and not defined($vema->{'centralities'})) {
      # ...checking that the $vema has been passed and that it is not the $poma...
      $vema=&modify_vema($a, $r, $d_count, $n, $vema, $poma);
    }
  }
  return $r;
}

sub modify_vema {
  my $a=$_[0];
  my $r=$_[1];
  my $d_count=$_[2];
  my $n=$_[3];
  my $vema=$_[4];
  my $poma=$_[5];
  # Check to see if a path for this neighbor author has already been stored...
  if(defined($vema->{$n}->{'d'})) {
    # Compare the stored distance to the newly calculated distance...
    if($vema->{$n}->{'d'} > $r->{'d'}->{$n}) {
      &store_vema_values($vema, $r, $n, $d_count);
      return $vema;
    }
    # ...and if the newly calculated distance is the same...
    else {
      # If $poma doesn't have a value for $a...
      if(not defined($poma->{'components'}) or not defined($poma->{'centralities'}->{$a}) or not defined($poma->{'power'}->{'common'}->{$a}) or not defined($poma->{'power'}->{'size'}->{$a})) {
        # ...proceed to the next author/aunex.
        next;
      }
      if(&compare_nodes_using_poma($vema->{$n}->{'e'}, $a, $poma) eq $a) {
        &store_vema_values($vema, $r, $n, $d_count);
        return $vema;
      }
    }
  }
  # ...and if a path hasn't been stored in the $vema for this neighbor author...
  else {
    # ...store the path.
    &store_vema_values($vema, $r, $n, $d_count);
    return $vema;
  }
}

sub store_vema_values_old {
  my $vema=$_[0];
  my $r=$_[1];
  my $n=$_[2];
  my $d_count=$_[3];
#  my $a=$_[4];

  # ...and if the newly calculated distance is shorter, replace it in the $vema... 
#  $vema->{$n}->{'d'}=$r->{'d'}->{$n};
  print Dumper $vema;
  $vema->{$n}->{'d'}=$d_count;

  # ...along with the new $vema path...
  # ...by, first, clearing the value of the old path...
  $vema->{$n}->{'p'}=undef;
  # ...then, by placing the neighbor author as the initial node of the path...
  $vema->{$n}->{'p'}=$n;
  my $z=$n;
  my $i_d_count=$d_count;
  # ...followed by concatenating an '_' and the 'predecessor author' for each binary step from the neighbor author.
  while($i_d_count > 0) {
    if(not defined($r->{'p'}->{$z})) {
      last;
    }
    $vema->{$n}->{'p'}.= ('_' . $r->{'p'}->{$z});
    $vema->{$n}->{'e'}=$r->{'p'}->{$z};

    $z=$r->{'p'}->{$z};
    $i_d_count--;
  }
  # Now, place the value of the ur-author of this shorter path into the $vema for this neighbor author.
  return 0;
}

## compute a set of edges, with Newman-style weights
## this function does not take account of status of aunex

# 01/08/11 - James
# I had completely forgotten about this.  Instead of implementing a function to compute a set of edges with Newman-style weights that does NOT take into account the status of the aunex, I had, instead, implemented a separate function JUST for dealing with status '0' aunexes, and then implemented another function to merge the edges computed for registered authors.  This is the rationale behind the &merge_nodes_reg_unreg and the &prepare_nodes_unreg_aun functions.



sub find_edges {
  ## this inupt 
  my $file=shift;
  my $dom=shift;
  print "doing: '$file'\n";
  my $doc=$dom->parse_file($file);
  my $root_element=$doc->documentElement();
  print Dumper &AuthorProfile::Common::get_aunexes_per_docid($root_element);
  
}


## compare nodes suing the poma pecking order
sub compare_nodes_using_poma {
  my $a=shift;
  my $b=shift;
  my $poma=shift;

  warn "WARNING: Empty \$a passed.\n" if not $a;
  warn "WARNING: Empty \$b passed.\n" if not $b;
  die "FATAL ERROR: poma wasn't loaded properly.\n" if not $poma;

  assert($a);
  assert($b);
  assert($poma);
  ## first, deal with the more likely case whore
  ## $a and $b are in the same component
  if($poma->{'components'}->{$a} == $poma->{'components'}->{$b}) {
    #print "$a and $b are in component $components->{'components'}->{$b}\n";
    ## if $a has larger centrality
    if($poma->{'centralities'}->{$a}>$poma->{'centralities'}->{$b}) {
      return $a;
    }
    ## if $b has larger centrality
    if($poma->{'centralities'}->{$b}>$poma->{'centralities'}->{$a}) {
      return $b;
    }
    ## case of equal centrality, same component, use power->{'common'}
    ## if $a has larger power->{'common'}
    if($poma->{'power'}->{'common'}->{$a}>$poma->{'power'}->{'common'}->{$b}) {
      return $a;
    }
    ## if $b has larger power->{'common'}
    if($poma->{'power'}->{'common'}->{$b}>$poma->{'power'}->{'common'}->{$a}) {
      return $b;
    }
    ## case of equal centrality, same component, use power->{'size'}
    ## if $a has larger power->{'size'}
    if($poma->{'power'}->{'size'}->{$a}>$poma->{'power'}->{'size'}->{$b}) {
      return $a;
    }
    ## if $b has larger power->{'size'}
    if($poma->{'power'}->{'size'}->{$b}>$poma->{'power'}->{'size'}->{$a}) {
      return $b;
    }
    ## this should not happen, but it may
    warn "poma can not distinguish $a from $b, common component\n";
    return $a;
  }
  ## $a and $b are in the different component, prefer larger component, first by members
  my $a_size=scalar keys %{$poma->{'components'}->{$poma->{'components'}->{$a}}};
  my $b_size=scalar keys %{$poma->{'components'}->{$poma->{'components'}->{$b}}};
  if($a_size>$b_size) {
    return $a;
  }
  if($b_size>$a_size) {
    return $b;
  }
  ## $a and $b are in the different component, prefer larger component, second by papers written by members
  $a_size=$poma->{'components'}->{$poma->{'components'}->{$a}}->{'size'};
  $b_size=$poma->{'components'}->{$poma->{'components'}->{$b}}->{'size'};
  if($a_size>$b_size) {
    return $a;
  }
  if($b_size>$a_size) {
    return $b;
  }
  ## case of equal component size, prefer larger power
  ## if $a has larger power->{'common'}
  if($poma->{'power'}->{'common'}->{$a}>$poma->{'power'}->{'common'}->{$b}) {
    return $a;
  }
  ## if $b has larger power->{'common'}
  if($poma->{'power'}->{'common'}->{$b}>$poma->{'power'}->{'common'}->{$a}) {
    return $b;
  }
  ## case of equal centrality, same component, use power->{'size'}
  ## if $a has larger power->{'size'}
  if($poma->{'power'}->{'size'}->{$a}>$poma->{'power'}->{'size'}->{$b}) {
    return $a;
  }
  ## if $b has larger power->{'size'}
  if($poma->{'power'}->{'size'}->{$b}>$poma->{'power'}->{'size'}->{$a}) {
    return $b;
  }  
  ## if $a has larger power
  ## this should not happen, but it may
  warn "poma can not distinguish $a from $b, different component size $a_size\n";
  return $a;
}


## weighted edges
sub weighted_network_edges {
  my $p=shift;
  my $edges_file_sym;
  my $t;
  my $w;
  foreach my $paper (keys %{$p}) {
    my @authors=@{$p->{$paper}};
    my $author_number=$#authors;
    #print "$paper author number $author_number\n";
    #print Dumper @authors;
    ## ignore papers with a single author
    if($author_number==0) {
      next;
    }
    foreach my $aut1 (@authors) {
      if(not defined($t->{$aut1})) {
        $t->{$aut1}=0;
      }
      foreach my $aut2 (@authors) {
        my $to_add=1/$author_number;
        if($aut2 eq $aut1) {
          next;
        }
        if(not defined($w->{$aut1}->{$aut2})) {
          $w->{$aut1}->{$aut2}=0;
        }
        #print "$aut1 to add $to_add\n";
        $w->{$aut1}->{$aut2}+=$to_add;
        $t->{$aut1}=$t->{$aut1}+$to_add;
      }
    }
  }
  #
  # inverse to find the symetric edges
  #
  my $e;
  foreach my $aut1 (keys %{$w}) {
    foreach my $aut2 (keys %{$w->{$aut1}}) {    
      $e->{$aut1}->{$aut2}=1/$w->{$aut1}->{$aut2};
    }
  }
  # store $e,"$edges_file_sym.dump";
  return $e;
}

# NOTE: This has been imported due to problems importing it from the Common.pm module

sub get_from_db_json {
  my $db=shift; 
  my $db_key=shift;
  my $json;
  #This was db_put?...
  #  my $return=$db->db_put($db_key, $json);
  my $return=$db->db_get($db_key, $json);
  if($return != 0 and not $return=~m|DB_NOTFOUND|) {
    warn "error in db_get: $return";
  }
  if(not $json) {
    return;
  }
  my $value=eval{
    decode_json $json;
  };
  my $error=$@;
  if($error) {
    warn "could not decode $json: $error";
    return;
  }
  return $value;
}

sub put_in_db_json {
  my $db=shift;
  my $db_key=shift;
  my $value=shift;
  my $json=encode_json($value);
  my $return=$db->db_put($db_key, $json);
  if($return != 0 ) {
    warn "error in db_put: $return";
    return;
  }
  return 1;
}



####################################################################

sub poma_stress_test {
  my $edges=shift;
  my $poma=shift;
  ## double loop through all authors
  foreach my $a (keys %{$edges}) {
    foreach my $b (keys %{$edges}) {
      ## don't compare equals
      if($a eq $b) {
        next;
      }
      my $result= "$a vs $b: ". compare_nodes_using_poma($a,$b,$poma)."\n";
      #print $result;
    }
  }
}


## this is the main node input, prepare p and n
sub prepare_nodes {
  my $person_dir=shift;
  ## the network
  my $n;
  foreach my $file (`find $person_dir -name '*.amf.xml'`) {
    chomp $file;
    my $root_element=&AuthorProfile::Common::get_root_from_file($file);
    ## we are looking at the first person noun, direct
    ## child of the root.
    my $person_element=$root_element->getChildrenByTagNameNS($amf_ns,'person')->[0];
    ## it is assumed to be the first name to appear
    my $id=$person_element->getChildrenByTagNameNS($acis_ns,'shortid')->[0];
    if(not $id) {
      print "no short id:";
      print $person_element->toString(1);
      print "\nin file $file\n";
      exit;
    }
    $id=$id->textContent;
    my $name=$person_element->getChildrenByTagNameNS($amf_ns,'name')->[0]->textContent;
    ## the person part of the network
    $n->{'p'}->{$id}->{'name'}=$name;
    ## is is assumed that the homepage of the person is the first homepage
    my $homepage_node=$person_element->getChildrenByTagNameNS($amf_ns,'homepage');
    my $homepage;
    if($homepage_node) {
      $homepage=$homepage_node->[0]->textContent;    
      $n->{'p'}->{$id}->{'homepage'}=$homepage;
    }
    ## now read the documents, part $n->{'d'}
    my @is_author_nodes=$person_element->getChildrenByTagNameNS($amf_ns,'isauthorof');
    foreach my $is_author_node (@is_author_nodes) {
      my @text_nodes=$is_author_node->getChildrenByTagNameNS($amf_ns,'text');
      foreach my $text_node (@text_nodes) {
        my $ref=$text_node->getAttribute('ref');
        if($ref) {
          push(@{$n->{'d'}->{$ref}},$id);
        }
      }
    }
  }
  return $n;
}

## find centralities for all nodes in all components
sub find_centralities {
  my $edge=shift;
  my $components=shift;
  my @authors=(keys %{$edge}) ;
  @authors=shuffle(@authors);
  my $centralities={};
  my $count_components=0;
  my $author_number=$#authors;
  foreach my $aut (@authors) {
    #print "starting author is $aut\n";
    if(not scalar $components->{$aut}) {
      print "autor $aut is a singleton\n";
      next;
    }
    ## returns a hash of ->{'d'} and ->{'p'}
    my $test_component=&find_component($aut,$edge);
    my $total=0;
    my $count_in_component=0;
    foreach my $member (keys %{$test_component->{'d'}}) {
      $total+=$test_component->{'d'}->{$member};
      $count_in_component++;
    }
    $centralities->{$aut}=$total/$count_in_component;
  }    
  return $centralities;
}


## finds all components
sub find_all_components {
  my $edge=shift;
  my $power=shift;
  my @authors=(keys %{$edge});
  @authors=shuffle(@authors);
  ## shows in what component the person is, if key string, and the
  ## component members, if key is a number
  my $components={};
  my $count_components=0;
  my $author_number=$#authors;
  foreach my $aut (@authors) {
    #print "starting author is $aut\n";
    if($components->{$aut}) {
      #print "already found in component\n";
      next;
    }
    ## returns a hash of ->{'d'} and ->{'p'}
    my $test_component=&find_component($aut,$edge);
    foreach my $member (keys %{$test_component->{'d'}}) {
      $components->{$member}=$count_components;
      $components->{$count_components}->{$member}=1;
      if(not defined($components->{$count_components}->{'size'})) {
        $components->{$count_components}->{'size'}=$power->{'size'}->{$member};
      }
      else {
        $components->{$count_components}->{'size'}+=$power->{'size'}->{$member};
      }
    }
    $count_components++;
    #print Dumper $test_component;
  }    
  return $components;
}


## compute binary edges
sub binary_network_edges {
  my $p=$_[0];
  # edges
  my $edge;
  foreach my $paper (keys %{$p}) {
    my @authors=@{$p->{$paper}};
    #print Dumper @authors;
    my $author_number=$#authors;
    my $author_1_count; 
    foreach my $aut1 (@authors) {
      foreach my $aut2 (@authors) {
        if($aut2 ne $aut1) {
          $edge->{$aut1}->{$aut2}++;
        }
      }
    }
  }
  return $edge;
}


## iteration to find component
sub find_component {
  my $a=$_[0];
  my $c=$_[1];
  my @c_keys=keys %{$c};
  my $c_count=$#c_keys;
  # main results variable
  my $r;
  # own distance is zero
  # distance counter
  my $d_count=0;
  $r->{d}->{$a}=$d_count;
  my $component_size;
  # next author 
  $d_count++;
  $r=&go_further_from($a,$r,$d_count,$c);
  my $new_size=1;
  my $old_size=0;
  my @p_keys=keys(%{$r->{p}});
  my $p_count=$#p_keys;
  # this while loop will not end if there are 
  # several components in the data
  while($old_size < $new_size) {
    $old_size=&component_size($r);
    #print "size: $old_size\n";
    $d_count++;
    if($d_count > $c_count*$c_count) {
      print "improbably large distance, several components?\n";
      exit;
    }
    #print "p_count $p_count\n";
    #print "c_count $c_count\n";
    foreach my $v (keys %{$r->{d}}) {
      if($r->{d}->{$v} == $d_count-1) {
        #print "doing $v $r->{d}->{$v} $d_count\n";
        ## in AuthorProfile::Network
        $r=&go_further_from($v,$r,$d_count,$c);
        $new_size=&component_size($r);
        #print Dumper $r;
        my @p_keys=keys(%{$r->{p}});
        $p_count=$#p_keys;
        #print "p_count $p_count\n";
      }
    }
  }
  # avoid nulling it later
  $r->{d}->{$a}=1;
  return $r;
}

#
# find size of component
#
sub component_size {
  my $r=$_[0];
  my @found=keys(%{$r->{d}});
  my $found_number=$#found+1;
  return $found_number;
}


## prepare the power strucute, a minor determinant
sub prepare_power {
  my $person_dir=shift;
  ## the power of a node
  my $power;
  foreach my $file (`find $person_dir -name '*.amf.xml'`) {
    chomp $file;
    my $root_element=&AuthorProfile::Common::get_root_from_file($file);
    ## we are looking at the first person noun, direct
    ## child of the root.
    my $person_element=$root_element->getChildrenByTagNameNS($amf_ns,'person')->[0];
    ## it is assumed to be the first name to appear
    my $id=$person_element->getChildrenByTagNameNS($acis_ns,'shortid')->[0];
    if(not $id) {
      print "no short id:";
      print $person_element->toString(1);
      print "\nin file $file\n";
      exit;
    }
    $id=$id->textContent;
    ## read document data
    my @accepted_nodes=$person_element->getChildrenByTagNameNS($amf_ns,'isauthorof');
    my $count_accepted_documents=scalar(@accepted_nodes) or next;
    my @refused_nodes=$person_element->getChildrenByTagNameNS($acis_ns,'hasnoconnectionto');
    my $count_refused_documents=scalar(@refused_nodes);
    ## how common is the name
    $power->{'common'}->{$id}=$count_refused_documents/$count_accepted_documents;
    ## how much is the size
    $power->{'size'}->{$id}=$count_accepted_documents;
  }
  return $power;
}

# COMPOSE POMA

## the parser, used globally
my $parser = XML::LibXML->new();

## developed offline
#$parser->no_network(1);
#$parser->load_ext_dtd(0);


sub generate_poma {

  ## run parameter 
  my $source='ac';
  my $net_type='mans';

  my $poma_file=shift;
  #  for (my $i=0; $ARGV[$i]; $i++) {
  #    if($ARGV[$i]=~m|--poma|) {
  #     $poma_file=$ARGV[$i];
  #      $poma_file=~s|--poma=||;
  #    }
  #  }

  if(not $poma_file) { $poma_file="$home_dir/ap/var/poma.json"; }

  ## make the person dir the argument
  #my $person_dir=$ARGV[0];

  my $person_dir;
  #for (my $i=0; $ARGV[$i]; $i++) { if(-d $ARGV[$i]) { $person_dir=$ARGV[$i]; }}
  
  #if(not $person_dir) {
  $person_dir="$home_dir/ap/amf/3lib/am";
  #}

  if(not -d $person_dir) {
    die "fatal: no such person_dir: $person_dir\n";
  }

  ## the power of a node, a minor poma determinator
  my $power=&prepare_power($person_dir);

  ## prepare node and document information
  my $network=&prepare_nodes($person_dir);
  my $texts=$network->{'d'};

  ## the edges
  my $edges=&weighted_network_edges($texts);

  ## find all components
  my $components=&find_all_components($edges,$power);

  ## finds centralities for non-singletons
  my $centralities=&find_centralities($edges, $components);
  
  ## define the poma
  my $poma;
  $poma->{'centralities'}=$centralities;
  $poma->{'components'}=$components;
  $poma->{'power'}=$power;
  
  ## store it
  #&json_store($poma,"$home_dir/opt/var/poma.pack");
  &AuthorProfile::Common::json_store($poma,$poma_file);


  
  ## stress test
  &poma_stress_test($edges,$poma);
  return;
}

sub retrieve_name_for_sid {
  my $sid=shift;
  my $auma=shift;

#  my $home_dir=$ENV{'HOME'};
#  if(not $home_dir) { $home_dir = '/home/mamf'; }
#  my $home_dir='/home/aupro';
#  my $acis_dir="$AuthorProfile::Conf::home_dir/ap/opt/amf/3lib/am";
#  my $acis_dir="$home_dir/ap/opt/amf/3lib/am";

  my @chars=split(//, $sid);

  my $file="$ap_dir/$chars[$#chars - 2]/$chars[$#chars - 1]/$sid.amf.xml";

  if(not -f $file) {
    warn("Could not find ACIS author record $file for author $sid.\n");
    return undef;
  }
  
  my $root_elem=$parser->parse_file($file)->documentElement();
  
  if(not defined($root_elem)) {
    warn("Could not obtain the root <element/> for author $sid.\n");
    return undef;
  }
  
  my $person_elem=$root_elem->getChildrenByTagName('person')->[0];

  if(not defined($person_elem)) {
    $person_elem=$root_elem->firstChild()->firstChild();
    if(not defined($person_elem)) {
      warn("Error: No <person/> element could be found in $sid's ACIS record $file by retrieve_name_for_sid.\n");
      return undef;
    }
  }
  
  my $name_elem=$person_elem->getChildrenByTagName('name')->[0];

  if(not defined($name_elem)) {
    $name_elem=$person_elem->firstChild()->firstChild();
    if(not defined($name_elem)) {
      warn("Could not obtain the <name/> root element for author $sid in ACIS record $file by retrieve_name_for_sid.\n");
      return undef;
    }
  }

  my $name=$name_elem->textContent();
  
  if(not defined($name)) {
    warn("Error: Empty contents for <name/> element for author $sid's ACIS record $file \(retrieve_name_for_sid\).\n");
    return undef;
  }
  return $name;
}


1;
