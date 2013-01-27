package AuthorProfile::Common;

use strict;
use warnings;
use utf8;
use open ':utf8';
use encoding 'utf8';
use lib qw( /home/aupro/ap/perl/lib /home/aupro/usr/lib/perl );

use BerkeleyDB;
use Data::Dumper;
use Encode;
use File::Slurp;
use JSON::XS;
use MongoDB;
use MongoDB::OID;
use XML::LibXML;
use XML::LibXSLT;
use AuthorProfile::Auvert qw( authorname_to_filename 
                              normalize_name ); 

use AuthorProfile::Conf;
use Exporter;
our @EXPORT_OK = qw( relate_name_element_to_authors
                     add_status 
                     open_db 
                     close_db
                     get_mongodb_collection
                     put_in_db_json
                     put_in_mongodb
                     get_from_db_json
                     get_from_mongodb
                     get_aunexes_per_docid
                     get_root_from_file
                     json_store
                     json_retrieve
                     updateMongoDBRecord
                     getMongoDBAuProRecord
                  );


## json decoder
#my $decoder=JSON::XS->new->utf8->pretty->allow_nonref;
my $g_json_coder = JSON::XS->new->utf8->pretty->allow_nonref;

## node master
#my $noma_db_file="/opt/wotan/home/mamf/opt/var/vertical/noma.db";
my $noma_db_file="/home/aupro/ap/var/noma.db";

## xslt processors
my $xslts;


# ## the directories and files
my $home_dir='/home/aupro';
my $auvert_dir="$home_dir/ap/amf/auverted";
my $amf_ns='http://amf.openlib.org';


my $debug=0;

## initialize auma
my $auma;

my $verbose=0;

my $parser=XML::LibXML->new();

##
## does xslt on a file in the public_html directory
##
sub load_xslt {
  my $xslt_file_name=shift;
  my $xslt = XML::LibXSLT->new();
  #$parser = XML::LibXML->new();
  ## the function can take a full file or can
  ## use the style directory
  my $style_doc;
  if(-f $xslt_file_name) {
    $style_doc = XML::LibXML->load_xml(location=>"$xslt_file_name", no_cdata=>1,no_blanks=>1);
  }
  else {
    $style_doc = XML::LibXML->load_xml(location=> "$AuthorProfile::Conf::xslt_dir/$xslt_file_name", 
                                       no_cdata=> 1,
                                       no_blanks=> 1 );
  }
  my $stylesheet = $xslt->parse_stylesheet($style_doc);
  return $stylesheet;
}


# my $error_style_doc = XML::LibXML->load_xml(location=>"$home_dir/xslt/ap_error.xslt.xml", no_cdata=>1,no_blanks=>1);
# my $error_stylesheet = $xslt->parse_stylesheet($error_style_doc);


  
## relates a name element to authors by adding attributs
## to the name elment in the dom
sub relate_name_element_to_authors {
  my $name_element=shift;
  if($name_element->hasAttribute("status")) {
    warn("<name/> element ", $name_element->toString(1), " passed to add_status already contains a status.\n");
    return;
  }
  if(not $name_element) {
    warn "Fatal error: Empty \$name_element passed to relate_name_element_to_authors.";
    return;
  }
  if(not defined($name_element->textContent)) {
    # Debug
    if($debug) {
      warn "Empty <name/> element found in text \$doc_id...";
    }
    return $name_element;
  }
  my $auma=shift;
  if(not $auma) {
    warn "Fatal: Empty \$auma passed to relate_name_element_to_authors.\n";
    return;
  }
  ## could also be determined here, but earier passed
  my $aunex_number=shift;
  if(not $aunex_number) {
    warn "Fatal error: Empty \$aunex_number passed to relate_name_element_to_authors.\n";
    return;
  }
  ## optional, to make a link to the own author
  ## this argumennt is not applicatble for
  my $au_id=shift;
  # 11/24/10 17:26 EST (GMT -5) - James
  my $statuses_found=shift;
  if(not defined($statuses_found)) {
    if($verbose) {
      warn "Empty hash passed to relate_name_element_to_authors.\n";
    }
    undef($statuses_found);
  }    
  # 11/24/1- 17:55 EST
  elsif(not ref($statuses_found) eq 'HASH') {
    #    if($verbose) {
    ##THIS IS WHERE THE ERROR IS OCCURRING!
      warn "Value of \$statuses_found argument passed to \$relate_name_element_to_authors is not a pointer to a hash.\n";
      warn "The value is instead: ";
      #      print Dumper ($statuses_found);
      #      print Dumper $aunex_number;
      #      exit;
      undef($statuses_found);
      #    }
    }
  ## the aunex, normalized, to set status to 1 for aunexes
  my $aunex=shift;
  ## find the text and it's handle
  my $po_element=$name_element->parentNode;
  my $relator_element=$po_element->parentNode;
  ## deal with invalid AMF 
  my $is_invalid_amf='';
  if(not (($po_element->nodeName eq 'person') or
     ($po_element->nodeName eq 'organization'))) {
    print "invalid AMF, does not contain p/o wrapper around the p/o\n";
    print "supposed p_o elemment is \n";
    print $po_element->toString(1);
    print "name elemment is \n";
    print $name_element->toString(1);
    print "supposed p_o nodeName is \n";
    print $po_element->nodeName;
    ## cheating, say the relator is the p/o
    $relator_element=$po_element;
    $is_invalid_amf=1;
  }
  my $text_element=$relator_element->parentNode;
  if($is_invalid_amf) {
    print "invalid AMF\n";
    print $text_element->toString;
  }
  ## a sanity check, to be deleted later
  #print $text_element->toString(1);
  if($text_element->nodeName ne 'text') {
    die "fatal: text element called ". $text_element->nodeName."\n";
  }
  my $doc_id=$text_element->getAttribute('ref'); 
  if(not $doc_id) { $doc_id=$text_element->getAttribute('id'); }
  if(not $doc_id) {
    warn "Fatal Error: The following entry has no ref attribute:\n",$name_element->toString;
    return;
  }
  my $name=$name_element->textContent();
  # 11/24/10 17:28 EST
  if(defined($statuses_found->{$name})) {
    # Debug
    if($debug) {
      warn "Found stored status $statuses_found->{$name}.\n";
    }
    $name_element->setAttribute("status", "$statuses_found->{$name}");
    # 11/24/10 18:25 EST
    # Adding the author short identifier where necessary.
    if(defined($auma->{$doc_id}->{$aunex_number})) {
      $name_element->setAttribute("id", "$auma->{$doc_id}->{$aunex_number}");
      return $name_element;
    }
  }  
  ## the case of a non-author
  ## the case of an author comes after this if
  if(not defined($auma->{$doc_id}->{$aunex_number})) {

    #    $name_element->setAttribute("debug-name", $name);
    #    $name_element->setAttribute("debug-aunex", $aunex);



    ## second argument used for debugging, can be left out
    my $file=&AuthorProfile::Auvert::authorname_to_filename($name, 'debug');
    # This is if the filename can not be generated for $name
    if(not defined($file)) {
      ## it sholud return, but we still have to mark the
      ## status as -1
      $statuses_found->{$name}='-1';
      $name_element->setAttribute("status", '-1');
      return $name_element;
    }
    # This is if the filename can be generated, but that file doesn't exist
    if(not -f $file) {
#      $file="$AuthorProfile::Conf::auverted_dir/$file";
      $file="$auvert_dir/$file";
      if(not -f $file) {
        $statuses_found->{$name}='-1';
        $name_element->setAttribute("status", '-1');      
        return $name_element;
      }
    }

    ## we have a file, but it is the own name?
    ## check the comment ...
    my $sibling_node=$text_element->nextSibling;
    if(defined $sibling_node) {
      #    my $counter=0;
      
      #    while(not $sibling_node and $counter < 1000) {      
      #      $sibling_node=$sibling_node->nextSibling;
      #      $counter++;
      #    }
      
      #    print(Dumper $sibling_node->nodeType());
      #    exit;
      
      #############PROBLEM
      
      ## if sibling is not a comment, move to the next
      my $count=0;
      
      #    if(not defined($sibling_node) or not $sibling_node or $sibling_node->toString(1) eq ' ') {
      #      $statuses_found->{$name}='0';
      #      $name_element->setAttribute("status", '0');
      #      return $name_element;
      #    }
      
      my $sibling_node_type=undef;
      eval { $sibling_node_type=$sibling_node->nodeType(); };
      if($@) {
        $statuses_found->{$name}='0';
        
        #DEBUG - REMOVE
        $name_element->setAttribute("debug-error", $!);
        
        
        $name_element->setAttribute("debug-nodetype", Dumper($sibling_node->nodeType()));
        
        $name_element->setAttribute("status", '0');
        return $name_element;
      }
      
      while($sibling_node_type != 8 and $count < 1000) {      
        $sibling_node=$sibling_node->nextSibling;
        
        eval { $sibling_node_type=$sibling_node->nodeType(); };
        if($@) {
          $statuses_found->{$name}='0';
          
          #DEBUG - REMOVE
          $name_element->setAttribute("debug-error", $!);
          if($sibling_node) { $name_element->setAttribute("debug-nodetype", Dumper($sibling_node->nodeType())); }
          $name_element->setAttribute("status", '0');
          return $name_element;
        }
        
        $count++;
      }
      my $comment=$sibling_node->textContent;
      ## fixme: we have to remove the whitespace here
      ## otherwise it is significantn
      $comment=~s|^ *||;
      $comment=~s| *$||;    
      my @comment_components;
      @comment_components=split(' ',$comment);
      my $own_author_number=$comment_components[1];
      if(not defined($own_author_number)) {
        warn "could not find own_author_number $own_author_number\n";
      }

      if(not defined($aunex_number)) {
        warn "could not find aunex_numebr $aunex_number\n";
      }
      if(defined($own_author_number) and defined($aunex_number) 
         and $own_author_number == $aunex_number) {
        $statuses_found->{$name}='1';
        $name_element->setAttribute("status", '1');
        return $name_element;
      }
    }
    if(defined($aunex) and $name eq $aunex) {
      $statuses_found->{$name}='1';
      $name_element->setAttribute("status", '1');
      return $name_element;
    }
    #DEBUG - REMOVE
    $name_element->setAttribute("debug-name", $name);
    $name_element->setAttribute("debug-aunex", $aunex);

    $statuses_found->{$name}='0';
    $name_element->setAttribute("status", '0');
    return $name_element;
  }
  ## here we are looking at the case of an author
  ## whethher this is is a profile text or not... 
  my $local_au_id=$auma->{$doc_id}->{$aunex_number};
  ##Set the attribute "auid" within the element <name> to $au_id
  $name_element->setAttribute("id", $local_au_id);
  ## this is for the ap_top case, $au_id known, given
  if(defined($au_id)) {
    ## Set the status to '1' for the/an author of the document
    if($auma->{$doc_id}->{$aunex_number} eq $au_id) {
      $statuses_found->{$name}='1';
      $name_element->setAttribute("status", '1');
      return $name_element;
    }
    ## this implies, if the status is 2, the 
    ## id= attribute must have been set on the name 
    $statuses_found->{$name}='2';
    $name_element->setAttribute("status", '2');
    return $name_element;
  }
  ## now the case of an aunex, au_id not given
  if(defined($auma->{$doc_id}->{$aunex_number})) {
    $statuses_found->{$name}='2';
    $name_element->setAttribute("status", '2');
    return $name_element;
  }
  warn "relate_name_element_to_authors: This was not processed: ", $name_element->toString(1), "\n";
  return $name_element;
}


sub get_aunexes_per_docid {
  my $root_element=shift;
  my @text_elements=$root_element->getElementsByTagNameNS($amf_ns,'text');
  my $aunex_hash;
  my $aunexes;
  foreach my $text_element (@text_elements) {
    ## check that this is not a refused paper!
    my $parent_element=$text_element->parentNode;
    my $node_name=$parent_element->nodeName;
    if($node_name eq 'acis:hasnoconnectionto') {
      next;
    }  
    ## assumed to be accepted
    my $doc_id=$text_element->getAttribute('ref');
    if(not $doc_id) {
      print "fatal: no doc_id in ". $text_element->toString(1);
      exit;
      # Check to determine if the document bears the element <frozen>
    }
    ## assumed to be an author's or editor's name
    my @name_elements=$text_element->getElementsByTagNameNS($amf_ns,'name');    
    my $count_aunex->{$doc_id}=0;
    foreach my $name_element (@name_elements) {
      if(not $name_element->textContent) {
        # If the <name> element is empty, just skip the <name> element entirely.
        next;
      }
      my $aunex=&normalize_name($name_element->textContent);
      # print($count_aunex->{$doc_id}, "\n");
      # print($aunex);
      $aunexes->{$doc_id}->[$count_aunex->{$doc_id}++]=$aunex;
    }
  }
  return $aunexes;
}

##
sub json_store {
  my $data=shift;
  my $file=shift;
  my $file_fh=new IO::File "> $file"; 
  if(not defined($file_fh)) {
    warn "could not open $file\n";
  }
  #  my $data_packed=encode_json($data);
  my $json_data=$g_json_coder->encode($data);
  print $file_fh $json_data;
  $file_fh->close;
}

## json
sub json_retrieve {
  my $file=shift;
  my $data_json=read_file($file);
  my $data=decode_json $data_json;
  return $data;
}

# 01/07/12: James
# Usage:
#     getMongoDBColl [SCALAR database name], [SCALAR collection name] [, [HASH connection options] ]
# A quick method of instantiating a MongoDB::Collection object
sub getMongoDBColl {

  my ($dbName,$collName,$options)=@_;
  my $conn;
  ref $options eq 'HASH' ? $conn=MongoDB::Connection->new($options)->get_database($dbName)->get_collection($collName) : $conn=MongoDB::Connection->new->get_database($dbName)->get_collection($collName);
  die "Fatal Error: Could not retrieve a new connection to the collection $collName in the MongoDB $dbName: $!" if not $conn;
  return $conn;
}

# 02/16/12 - James

sub getMongoDBAuProRecord {
  my ($collName,$connOptions,$mongoDBQuery)=@_;
  my $coll=getMongoDBColl('authorprofile',$collName,$connOptions);
  my $cursor=eval{$coll->find($mongoDBQuery)};
  die $! if $@;
  return $cursor;

  #my @records;
  #while(my $record=$cursor->next) {
  #  push(@records,$record);
  #}

  #return @records;
}


sub get_from_mongodb {

  # 01/05/12: James
  # Absurd approach - left to ensure compliance with the BerkeleyDB handler
  my $collec=shift;

  # Temporary
  # $collec=MongoDB::Connection->new->get_database('authorprofile')->get_collection('noma') or die "Fatal Error: Could not retrieve a new connection to the MongoDB collection authorprofile.noma: $!";
  
  my $query_values=shift;
  my $key=shift;

  my $cursor;

  if(not $collec) {
    warn 'Empty collec passed to the MongoDB';
    return;
  }

  if(ref($query_values) eq 'HASH') {
    eval { $cursor=$collec->find($query_values); };
  }
  else {
    if($key) {
      eval { $cursor=$collec->find({$key => $query_values}); };
    }
    else {
      warn "Error: get_from_mongodb passed a non-hash parameter with no key";
      return;
    }
  }
  if($@ or (not $cursor)) {
    warn "Error in retrieving values with the following query:\n",Dumper $query_values,"\n from the MongoDB: $!";
    return
  }
#  return $cursor->next;

  my @objs;
  while(my $obj=$cursor->next) {
    if(exists $obj->{'_id'}) {
      delete $obj->{'_id'};
    }
    push(@objs,$obj);
  }

  return @objs;
}

sub get_from_db_json {
  my $db=shift; 
  my $db_key=shift;
  my $json;
  my $value=$db->db_get($db_key, $json);
  if($value != 0 and not $value=~m|DB_NOTFOUND|) {
    warn "error in db_get: $value";
  }
  if(not $json) {
    return;
  }
    #  my $json=encode_json $value;
#    my $json=$decoder->decode($value);
    #decode_json $json;
  eval{ $value=$g_json_coder->decode($json); };
  if($@) {
    warn "could not decode json value for key '$db_key': $!";
    return undef;
  }
  return $value;
}

## 
sub put_in_mongodb_old {

  # The MongoDB collection handler
  my $collec=shift;

  # The value(s) to be inserted (can be either a hash or a scalar)
  my $values=shift;
  # Determine the field to query in order to find existing records to update
  # e.g.
  # VID: 'aunex' (for the unique author name expression)
  # noma: 'author' (for the unique AuthorClaim short ID)
  my $query_key=shift;
  # Whether or not we should save the record as a duplicate if it already exists
  my $force_save=shift;
  if(not $query_key) {
    warn 'Empty $query_key value passed to put_in_mongodb: this may result in duplicate records being saved to ',$collec->name,'...';
    $force_save=1;
  }
  # If $values is a scalar, the key to form the hash
  my $key=shift;

  my $cursor;
  my @objs;

  if(not $values) {
    warn "Error: put_in_mongodb passed an empty value";
    return;
  }

  # If $values is a hash...
  if(ref($values) eq 'HASH') {
    # Wrong, one needs to determine whether or not the record already exists.
    # If it already exists, then we update (rather than save) the record.

    if($force_save) {
      # Save the record, even if it's a duplicate.
      eval { $cursor=$collec->save($values); };
    }
    else {
    # ...find a record matching the value(s) of the field $query_key.
      @objs=$collec->find({$query_key => $values->{$query_key}});
      if(not @objs) {
        # If no records were found, save the record as a new record.
        eval { $cursor=$collec->save($values); };
      }
      else {
        # Get the first record returned
        my $obj=pop @objs;
        $obj=$obj->next;

        # Get the value of '_id'
        my $record_id=$obj->{'_id'}->{'value'};
        die Dumper $record_id;
        # Ignore
        # Fill the record fields with the updated values passed to the subroutine
#        foreach my $values_key (keys %{$values}) {
#          $obj->{$values_key}=$values->{$values_key};
#        }
        die Dumper $obj;
        $cursor=$collec->update(%{$obj});
        die Dumper $cursor;
        # Update the database with this updated record
        eval { $cursor=$collec->update(%{$obj}); };
      }
    }
  }
  # If $values is a scalar...
  else {
    if(not $key) {
      warn "Error: put_in_mongodb passed a non-hash parameter with no key";
      return;
    }
    if($force_save) {
      # Save the record, even if it's a duplicate.
      eval { $cursor=$collec->save({$key => $values}); };
    }
    else {
      # ...find a record matching the value(s) of the field $query_key.
      @objs=$collec->find({$query_key => $values});
      if(not @objs) {
        # If no records were found, save the record as a new record.
        eval { $cursor=$collec->save({$key => $values}); };
      }
      else {
        my $obj=pop @objs;
        $obj->{$key}=$values;
        eval { $cursor=$collec->update($obj); };
      }
    }
  }
  if($@ or (not $cursor)) {
    warn "Error in saving/updating $values into MongoDB: $!";
    return
  }
  return $cursor;
}

# 01/07/12 - James
# Usage:
#     updateMongoDBRecord [SCALAR database name], [SCALAR collection name], [HASH JSON query], [HASH script] [, [HASH update options] [, [SCALAR number of transaction attempts ] ] ]
# This is derived from the method MongoDB::Collection::update( [HASH query], [HASH script] [, [HASH options] ])
# This instantiates and closes a MongoDB::Connection for each transaction.
sub updateMongoDBRecord {

  my ($dbName,$collName,$query,$script,$options)=@_;

  my $conn=getMongoDBColl($dbName,$collName) or die "Fatal: Could not retrieve a connection for updateMongoDBRecord: $!";

  if($options) {
    die 'Fatal: Non-hash value passed for options to updateMongoDBRecord' if ref $options ne 'HASH';
  }

  # Default to 5 update attempts
  my $maxAttempts=5;
  $maxAttempts=$_[5] if $_[5];

  # Recurse infinitely for a maxAttempt value of -1
  if ($maxAttempts == -1) {

    warn "Attempting infinite recursion for updateMongoDBRecord\n";
    do {
      eval { $conn->update($query,$script,$options); };
    } while ($@);
  }
  else {

    my $i=0;
    eval { $conn->update($query,$script,$options); };
    while ($@ and $i <= $maxAttempts + 1) {

      eval { $conn->update($query,$script,$options); };
      last if not $@;
      $i++;
    }
    die "updateMongoDBRecord failed for:\n",Dumper $query,"\n",Dumper $script,"\nin $dbName.$collName after $maxAttempts attempts: $!\n",Dumper @_ if $i == $maxAttempts;
  }
  undef $conn;
  return;
}

# 01/07/12 - James
# Usage:
#     put_in_mongodb [MongoDB::Collection] [HASH values] | [SCALAR value hash value], [SCALAR query hash key], [SCALAR query hash value] [, [SCALAR value hash key] ]
# This is derived from the method MongoDB::Collection::update( [HASH query], [HASH script] [, [HASH options] ])
sub put_in_mongodb {

  # The MongoDB collection handler
  my $collec=shift;

  # The value(s) to be inserted (can be either a hash or a scalar)
  my $values=shift;

  my $query_key=shift;
  if(not $query_key) {
    die 'Fatal Error: No query key passed to put_in_mongodb';
  }
  my $query_value=shift;
  if(not $query_value) {
    $query_value=$values->{$query_key};
    if(not $query_value) {
      die 'Fatal Error: No query value passed to put_in_mongodb';
    }
  }

  # Determine the field to query in order to find existing records to update
  # e.g.
  # VID: 'aunex' (for the unique author name expression)
  # noma: 'author' (for the unique AuthorClaim short ID)

  # If $values is a scalar, the key to form the hash
  my $key=shift;

  my $results;
  my @objs;

  if(not $values) {
    warn "Error: put_in_mongodb passed an empty value";
    return;
  }

  # If $values is a hash...
  if(ref($values) eq 'HASH') {

    # Using the option 'upsert'...
    # If the record already exists, then the record is updated (rather than saved).
    if(not $query_value) {
      $query_value=$values->{$query_key};

      if(not $query_value) {
        warn 'Undefined query value passed to MongoDB';
        return;
      }
    }
    if(exists $values->{'_id'}) {
      delete $values->{'_id'};
    }
    if(exists $values->{$query_key}) {
      delete $values->{$query_key};
    }
    eval { $results=$collec->update({$query_key => $query_value}, {'$set' => $values},{'upsert' => 1, 'multiple'=> 0}); };
  }
  # If $values is a scalar...
  else {
    if(not $key) {
      warn "Error: put_in_mongodb passed a non-hash parameter with no key";
      return;
    }
    if(not $query_value) {
      $query_value=$values;
    }

    eval { $results=$collec->update({$query_key => $query_value}, {'$set' => {$key => $values}},{"upsert" => 1, "multiple" => 0}); };
  }
  if($@ or (not $results)) {
    warn "Error in saving/updating record(s) with the following values:\n",Dumper $query_key,Dumper $query_value,Dumper $values,"\ninto MongoDB: $!";
    return
  }
  # This should return 0
  return $results;
}

## 
sub put_in_db_json {
  my $db=shift;
  my $db_key=shift;
  my $value=shift;

#  my $encoder=JSON::XS->new->utf8->pretty->allow_nonref;
#  my $json=encode_json $value;
#  my $json=$encoder->encode($value);

  my $json;
  eval{ $json=$g_json_coder->encode($value); };
  if($@) {
    warn "could not encode the following value\(s\):\n",Dumper $value,"for key '$db_key': $!";
    return undef;
  }


  my $return=$db->db_put($db_key, $json);
  if($return != 0 ) {
    warn "error in db_put: $return";
    return;
  }
  return 1;
}

## open a db
sub open_db {
  my $file=shift;
  my $db = eval { 
    new BerkeleyDB::Hash(-Filename => $file, 
                         -Flags  => DB_CREATE);
  };
  if($@) {
    $db=undef;
    warn "$@";
  }
  return $db;
}

## close a db
sub close_db {
  my $db=shift;
  $db = eval { 
    $db->db_close;
  };
  if($@) {
    $db=undef;
    warn "$@";
  }
  return;
}

sub get_mongodb_collection {
  my $collec_name=shift;
  my $db_name=shift;

  if(not $collec_name) {
    warn "Error: No collection specified for get_mongodb_collection";
    return;
  }

  $db_name='authorprofile' if not $db_name;  

  my $collec;

  my $conn = MongoDB::Connection->new or die "Fatal Error: Could not retrieve a new MongoDB connection: $!";
  my $db = $conn->get_database($db_name) or die "Fatal Error: Could not retrieve a MongoDB::Database handler for $db_name: $!";
  eval {
    $collec = $db->get_collection($collec_name);
  };
  if($@) {
    warn "Error: get_mongodb_collection could not retrieve the MongoDB::Collection handler: $!";
    return
  }

  return $collec;
}

## gets root element from file
sub get_root_from_file {
  my $in_file=shift;
  if(not $in_file) {
    print "no such file: $in_file\n";
    return undef;
  }
  my $fh;
  open $fh, $in_file;
  if(not defined($fh)) {
    warn "could not open $in_file";
    return;
  }
  binmode $fh; # drop all PerlIO layers possibly created by a use open pragma                                                               
  my $oai_dc_doc = $parser->parse_fh($fh);
  close $fh;
  $oai_dc_doc->toString();
  my $root_element=$oai_dc_doc->documentElement;
  return $root_element;
}

sub add_status {
  my $root_element=shift;
  my $auma=shift;
  ## optional, if we have to take account of the aunex
  my $aunex=shift;
  my @text_elements=$root_element->getElementsByTagNameNS($amf_ns,'text');

  my %found_statuses;

  foreach my $text_element (@text_elements) {
     my @name_elements=$text_element->getElementsByTagNameNS($amf_ns,'name');
     # This is the hash that is to store author statuses once they've been calculated once (rather than wasting resources by calculating the same author's status each time that it occurs).
     my $aunex_number=0;
     foreach my $name_element (@name_elements) {
       $aunex_number++;
       ## $au_id is argument is optional, not used here

       if($name_element->hasAttribute("status")) {
         warn("<name/> element ", $name_element->toString(1), " passed to add_status already contains a status.\n");
         return $root_element;
       }

       # The parameters for this function are STRICTLY as follows:
       # &relate_name_element_to_authors([NAME ELEMENT], [AUMA], [AUNEX NUMBER], [AUTHOR ID], [STATUSES FOUND], [AUNEX])

       
       $name_element=&relate_name_element_to_authors($name_element,$auma,$aunex_number,0,\%found_statuses,$aunex);

#       print $name_element->toString(1);
#       exit;

     }
   }
  
  return $root_element;
}

## find profile file from psid
sub psid_to_profile_file {
  my $psid=shift;
  if(not $psid=~m|p([a-z])([a-z])\d+$|) {
    warn "illegal psid '$psid'";
    return;
  }
  return "$ap_dir/$1/$2/$psid.amf.xml";
}



## cheers!
1;
