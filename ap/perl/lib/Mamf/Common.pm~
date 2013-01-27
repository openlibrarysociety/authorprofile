package Mamf::Common;

=head1 NAME

Mamf::Common -- Common routines

=cut

require Exporter;

use lib qw ( /home/mamf/usr/lib/perl/ );

use strict;
use warnings;
use Data::Dumper;
#use Data::MessagePack;
use JSON::XS;
use File::Basename;
use File::Compare;
use File::Find;
use File::Copy;
use File::Path;
use File::Slurp;
use File::Temp qw/ tempfile tempdir /;
use List::Util qw(shuffle);
use Unicode::String qw(utf8 latin1 utf16be uhex);
use XML::LibXSLT;
use XML::LibXML;
use XML::XPath;
use XML::XPath::XMLParser;


our @ISA = qw(Exporter);
our @EXPORT_OK = qw(save_work transform_to_numeric save_diff
                    make_amf_from_handle_hash
                    save_diff_xml integrate_file
                    make_amf_text number_to_file
                    get_root_from_file id_to_ref
                    put_in_db get_from_db print_value
                    amf_file_open
                    get_from_db_mp
                    get_from_db_json
                    put_in_db_mp
                    put_in_db_json
                    linify_xml get_document_from_file
                    file_to_handle_hash 
                    create_amf_element
                    integrate_dir);



## a global file counter to implement
## restrictions of files converted 
## across a raneg of directories
our $files_count=0;

## a global parser 
our $parser = XML::LibXML->new();
$parser->keep_blanks(0);
$parser->recover_silently(1);

##
## run settings
##
our $verbose=0;
our $do_delete_tmp=1;

##
## namespaces
##
our $amf_ns='http://amf.openlib.org';
our $amf_prefix='amf';
our $dc_ns='http://purl.org/dc/elements/1.1/';
our $dc_prefix='dc';
our $dmf_prefix='dmf';
our $dmf_ns='http://dmf.uni-bielefeld.de';

our $xpc = XML::LibXML::XPathContext->new;
$xpc->registerNs($amf_prefix, $amf_ns);
$xpc->registerNs($dc_prefix, $dc_ns);

 
## data constants  
my $amf_start='<amf xmlns="http://amf.openlib.org" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://amf.openlib.org http://amf.openlib.org/2001/amf.xsd">';
my $amf_end='</amf>';
my $general_prefix='info:lib';



sub get_from_db_json {
  my $db=shift; 
  my $db_key=shift;
  my $errors=shift;

  my $quiet=shift;

  if(ref($errors) ne 'SCALAR') {
    $quiet=$errors;
  }

  my $packed;
  #This was db_put?...
  #  my $return=$db->db_put($db_key, $packed);
  my $return;

  if(not $db) { die $db; }

  eval { $return=$db->db_get($db_key, $packed); };
  if($@) {
    warn "error in db_get: $!";
    warn "value of \$db was $db\n";
    warn "value of \$db_key was $db_key\n";
    warn "value of \$packed was $packed\n";
  }
  if(not $packed) {
    if($quiet) {
      if(ref($errors) eq 'SCALAR') { $$errors=$db->status; }
      return;
    }

    warn $db->status;
    warn "value of \$db was $db\n";
    warn "value of \$db_key was $db_key\n";
    warn "value of \$packed was $packed\n";

    if(not $db->status) { die; }
    $$errors=$db->status;
    return;
  }
#  my $value=eval{Data::MessagePack->unpack($packed);};
  my $value=eval{decode_json($packed);};

  my $error=$@;
  if($error) {
    warn "error in unpacking: $error\n";
    $$errors=$db->status;
    return;
  }
  if(not $value) {
    warn $db->status;
  }
  return $value;
}

# Deprecated - use get_from_db_json

sub get_from_db_mp {
  my $db=shift; 
  my $db_key=shift;
  my $errors=shift;
  my $packed;
  #This was db_put?...
  #  my $return=$db->db_put($db_key, $packed);
  my $return;
  eval { $return=$db->db_get($db_key, $packed); };
  if($@) {
    warn "error in db_get: $!";
  }
  if(not $packed) {
    warn $db->status;
    $$errors=$db->status;
    return;
  }
#  my $value=eval{Data::MessagePack->unpack($packed);};
  my $value=eval{decode_json($packed);};

  my $error=$@;
  if($error) {
    warn "error in unpacking: $error\n";
    $$errors=$db->status;
    return;
  }
  if(not $value) {
    warn $db->status;
  }
  return $value;
}

sub get_from_db {
  my $db=shift; 
  my $db_key=shift;
  my $frozen;
  my $return=$db->db_put($db_key, $frozen);
  if($return != 0) {
    print "error in db_get: $return\n";
  }
  my $value=eval{thaw $frozen;};
  my $error=$@;
  if($error) {
    print "error in thaw: $error\n";
    return;
  }
  return $value;
}

sub put_in_db_json {
  my $db=shift;
  my $db_key=shift;
  my $value=shift;
  my $packed;
#  eval { $packed=Data::MessagePack->pack($value); };
  eval { $packed=encode_json($value); };

  if($@) { die $!; }
  my $return;
  eval { $return=$db->db_put($db_key, $packed); };
  if($@) { die $!; }
  if($return) {
#    print "error in db_put: $return\n";
    return;
  }
}

# Deprecated - use put_in_db_json

sub put_in_db_mp {
  my $db=shift;
  my $db_key=shift;
  my $value=shift;
  my $packed;
#  eval { $packed=Data::MessagePack->pack($value); };
  eval { $packed=encode_json($value); };

  if($@) { die $!; }
  my $return;
  eval { $return=$db->db_put($db_key, $packed); };
  if($@) { die $!; }
  if($return) {
#    print "error in db_put: $return\n";
    return;
  }
}

sub put_in_db {
  my $db=shift;
  my $db_key=shift;
  my $value=shift;
  my $frozen=nfreeze $value;
  my $return=$db->db_put($db_key, $frozen);
  if($return) {
    print "error in db_put: $return\n";
    return;
  }
  return 1;
}


## finds largest number part in an identifier, obsolete (?)
sub transform_to_numeric {
  my $in=shift;
  my $letter_count=0;
  my $max_component;
  my $max_component_size=0;
  my $current_component_size=0;
  my $current_component;
  ## find largest number component
  while($letter_count < length($in)) {
    my $letter=substr($in,$letter_count,1);    
    if($letter=~m|[0-9]|) {
      $current_component.=$letter;
      $current_component_size=length($current_component);
      if(length($current_component) > $max_component_size) {
        $max_component_size=$current_component_size;
        $max_component=$current_component;
      }
    }
    else {
      $current_component='';
    }
    $letter_count++;
  }
  return $max_component;
}


## save full copy of work, no integration, no deletion
sub save_work {
  my $tmp_dir=shift;
  my $amf_dir=shift;
  my $debug=0;
  if($debug) {
    print "saving work\n";
  }
  foreach my $file (`find $tmp_dir -type f`) {
    chomp $file;
    $file=~s|^$tmp_dir/||;
    if($debug) {
      print "file: $file\n";
    }
    &wrap_file_with_amf_element_and_save_if_change($tmp_dir,$amf_dir,$file);
  }
  &clear_destination_files($tmp_dir,$amf_dir);
}


## wraps with AMF, saves to full part
sub wrap_file_with_amf_element_and_save_if_change {
  my $tmp_dir=shift;
  my $amf_dir=shift;
  my $tmp_file=shift;
  my $data_tmp_file="$tmp_dir/$tmp_file";
  if(not -f $data_tmp_file) {
    print "no such file: $data_tmp_file\n";
    return;
  }
  open(F,"sort $data_tmp_file |");
  binmode(F,":utf8:");
  my $in;
  while(<F>) {
    $in.=$_;
  }
  ## deal with empty file
  if(not $in) {
    return;
  }
  ## note absence of \n after $in
  $in="$amf_start\n$in$amf_end\n";
  my $main_data_tmp_file_name=$data_tmp_file;
  $main_data_tmp_file_name=~s|$tmp_dir/||;
  my $destination="$amf_dir/$main_data_tmp_file_name";
  #if($verbose > 0) {
  #  print LOG "calling save_diff $in $destination\n";
  #}
  &save_diff($in,$destination);
  return 1;
}


##
## checks if there is a difference, save otherwise
##
sub save_diff {
  my $contents=$_[0];
  my $destination=$_[1];
  my $dir=dirname($destination);
  if(not -d $dir) {
    mkpath($dir);
  }
  my ($fh, $tmp_file) = tempfile(DIR => '/tmp');
  binmode($fh,":utf8:");
  print $fh $contents;
  close $fh;
  if(-f $destination and -f $tmp_file and 
     not compare($destination,$tmp_file)) {
    system("rm $tmp_file");
    return;
  }
  copy($tmp_file,$destination);
  system("rm $tmp_file");

}  

## 
## normalizes whitespace 
## 
sub normalize_whitespace {
  my $in=shift;
  $in=~s|\s| |g;
  $in=~s|\s+| |g;
  $in=~s|^\s||g;
  $in=~s|\s$||g;
  return $in;
}



##
## do all file in the in_dir 
## 
sub convert_files_recursively {
  my $in_dir=shift;
  my $type=shift;
  my $stylesheet=shift;
  my $tmp_dir=shift;
  my $max_files=shift;
  if(not defined($tmp_dir) or not $tmp_dir) {
    $tmp_dir = tempdir( CLEANUP => $do_delete_tmp);
  }
  my $file_count=shift;
  if(not defined($file_count)) {
    $file_count=0;
  }
  my $debug=0;
  foreach my $file (shuffle `ls $in_dir`) {
    chomp $file;
    if($debug) {
      print "file is $file, type is $type\n";
    }    
    ## call recursively on a directory
    my $new_in_dir='';
    if(-d "$in_dir/$file") {
      $new_in_dir="$in_dir/$file";
      if($debug) {
        print "new_in_dir is $new_in_dir\n";
      }
    }
    elsif(-d "$file") {
      $new_in_dir="$file";
      if($debug) {
        print "new_in_dir is $new_in_dir\n";
      }
    }
    if($new_in_dir) {
      if($debug) {
        print "new in_dir is $new_in_dir\n";
      }
      &convert_files_recursively($new_in_dir,$type,$stylesheet,$tmp_dir,$max_files, $file_count);
    }
    ## dmf has no .xml ;-(
    if(not $file=~m|\.XML$|i and (not $type eq 'dmf') and (not -d "$in_dir/$file")) {
      print "next in convert_files_recursively on '$file'\n";
      next;
    }
    $file=basename($file);
    if($debug) {
      print "start work with $file in $in_dir\n";
    }
    my $is_ok=&work_with_file($file,$in_dir,$tmp_dir,$type,$stylesheet);
    ## if an error orrurs, return
    if(not $is_ok) {
      next;
    }
    if($max_files and $files_count > $max_files) {
      print "hitting last file, not installing\n";
      ## return to prevent an installation
      return;
    }
    $files_count++;
  }
  ## return $tmp_dir to signal success
  return $tmp_dir;
}



sub convert_files {
  my $in_dir=shift;
  my $tmp_dir = tempdir( CLEANUP => $do_delete_tmp);
  my $type=shift;
  my $stylesheet=shift;
  my $max_files=shift;
  my $debug=1;
  foreach my $file (shuffle `ls $in_dir`) {
    chomp $file;
    if($debug) {
      print "file is $file, type is $type\n";
    }    
    ## dmf has no .xml ;-(
    if(not $file=~m|\.xml$| and (not $type eq 'dmf')) {
      next;
    }
    my $is_ok=&work_with_file($file,$in_dir,$tmp_dir,$type,$stylesheet);
    ## if an error orrurs, return
    if(not $is_ok) {
      return;
    }
    if($max_files and $files_count > $max_files) {
      print "hitting last file\n";
      ## return to prevent an installation
      return;
    }
    $files_count++;
  }
  ## return $tmp_dir to signal success
  return $tmp_dir;
}

sub convert_files_with_find {
  my $in_dir=shift;
  my $tmp_dir = tempdir( CLEANUP => $do_delete_tmp);
  my $type=shift;
  my $stylesheet=shift;
  my $max_files=shift;
  my $debug=0;
  foreach my $file (shuffle `find $in_dir -type f`) {
    chomp $file;
    $file=~s|\Q$in_dir\E||;
    if($debug) {
      print "file is $file, type is $type\n";
    }    
    ## dmf has no .xml ;-(
    if(not $file=~m|\.xml$| and (not $type eq 'dmf')) {
      next;
    }
    my $is_ok=&work_with_file($file,$in_dir,$tmp_dir,$type,$stylesheet);
    if($debug) {
      print "worked with file $file\n";
    }
    ## if an error orrurs, return
    if(not $is_ok) {
      print "problem\n";
      return;
    }
    if($max_files and $files_count > $max_files) {
      print "hitting last file\n";
      ## return to prevent an installation
      return;
    }
    $files_count++;
  }
  ## return $tmp_dir to signal success
  return $tmp_dir;
}



## converts a file to AMF
sub work_with_file {
  ## the file
  my $in_file=shift;
  ## its directory
  my $in_dir=shift;
  ## temporarary diretory
  my $tmp_dir=shift;
  ## type type identifier, for id_to_file
  my $type=shift;
  ## the stylesheet, a xml::libxslt object
  my $stylesheet=shift;
  my $debug=0;
  if($in_dir) {
    $in_file="$in_dir/$in_file";
  }
  my $out;
  if(not -f $in_file and not -d $in_file) {
    warn "I could not open $in_file, leaving work_with_file\n";
    return;
  }
  if($debug) {
    print "in_file is $in_file\n";
  }
  my $inx=$parser->parse_file($in_file);
  my $amf=$stylesheet->transform($inx)->documentElement;
  my @text_elements = $amf->getChildrenByTagName('text');
  my $t;
  foreach my $t (@text_elements) {
    my $id=$t->getAttribute('id');
    my $file;
    if(not defined($Mamf::Bridges::id_to_file)) {
      print "fatal: no bridges\n";
      exit;
    }
    ## if a bridge exists, use that
    if(defined($Mamf::Bridges::id_to_file->{$type})) {      
      $file=$tmp_dir.'/'.&{$Mamf::Bridges::id_to_file->{$type}}($id,$t,$in_file).'.amf.xml';
      if($debug) {
        print "out_file is $file\n";
      } 
    }
    ## default: take the same file name
    else {
      print "no brigde, using default conversion of files\n";
      $file=basename($in_file);
      $file=~s|\.xml$|.amf.xml|;
      $file="$tmp_dir/$file";
    }
    if($debug) {
      print "out_file is $file\n";
    }
    my $dir=dirname($file);
    if(not -d $dir) {
      mkpath $dir;
    }
    my $line=&linify_xml($t->toString);
    open(OUT,">> $file");
    binmode(OUT,":utf8");
    chomp $line;
    print OUT "$line\n";
    close OUT;
  }
  return 1;
}

## checks if there is a difference, save otherwise
sub save_diff_xml {
  my $contents=shift;
  my $destination=shift;
  my $dir=dirname($destination);
  if(not -d $dir) {
    mkpath($dir);
  }
  my ($fh, $tmp_file) = tempfile(DIR => '/tmp');
  ## contents is assuemed to be an LibXML document
  $contents->toFile($tmp_file,1);
  if(-f $destination and 
     not compare($destination,$tmp_file)) {
    unlink $tmp_file;
    if($verbose) {
      print LOG "file $destination not changed\n";
    }
    return;
  }
  ## copy over if different
  copy($tmp_file,$destination);
  if($verbose) {
    print LOG "new version of file $destination written\n";
  }
  unlink $tmp_file;
}

## makes line out of xml
sub linify_xml {
  my $in=shift;
  ## remove whitespace
  $in=~s|>\s+<|><|g;
  $in=~s|\s+| |g;
  $in=~s|^\s+||g;
  $in=~s|\s+$||g;
  $in="$in\n";
  return $in;
}

## gets first child that is an element
sub first_element_child {
  my $xml=shift;
  foreach my $child_node ($xml->childNodes) {
    my $type=$child_node->nodeType;
    # element type
    if($type==1) {
      return $child_node;
    }
  }
}


## routine to read and return a file as a set of ids, hash
sub file_to_handle_hash {
  ## this is the file name
  my $file=shift(); 
  ## this is what gets return, a pointer
  my $o;
  # open the file
  open(F,"< $file");
  # assume the file is utf8
  binmode(F,":utf8:");
  # read the file
  while(<F>) {
    # check if there is an id
    if(not m:<text (id|ref)="([^"]+)":) {
      # ignore such a line
      next;
    }
    ## get the handle
    my $handle=$2;
    $o->{$handle}=$_;
  }
  # close the file
  close F;
  # return the output as file contents
  return $o;
}


##
sub integrate_file {
  my $old_file=shift;
  my $new_file=shift;
  my $old;
  my $new; 
  # look at the old_file, check if is there
  if(-f $old_file) {
    $old=&file_to_handle_hash($old_file);
  }
  else {
    ## give error note
    ## print "no such initial file $final_file, continue\n";
    ## this is not fatal
  }
  # read the patch_file
  $new=&file_to_handle_hash($new_file);
  ## main loop over contents of path
  foreach my $handle (keys %{$new}) {
    ## take it easy, just replace
    $old->{$handle}=$new->{$handle};
  }
  ## make amf
  my $amf_doc=&make_amf_from_handle_hash($old);
  ## make final save
  &save_diff($amf_doc,$old_file);
}


## makes amf out of a handle hash
sub make_amf_from_handle_hash {
  # accepts a pointer to a hash
  my $handle_hash=shift;
  # the output string
  my $out;
  # loop over the ids
  foreach my $handle (sort keys %{$handle_hash}) {
    # append value
    $out.=$handle_hash->{$handle};
  }
  # add amf start, defined globally
  $out=$amf_start."\n".$out;
  # add amf start, defined globally
  $out=$out.$amf_end."\n";
  return $out; 
}





## changes id to ref attribute
sub id_to_ref {
  my $element=shift;
  my $id_attribute_value=$element->getAttribute('id');
  ## fixme: this needs to go, hopefully soon! 
  $id_attribute_value=~s|^info:3lib:|info:lib/|;
  $element->removeAttribute('id');
  $element->setAttribute('ref',$id_attribute_value);
  return $element; 
}


## canonical AMF reader, read amf file of line structure
sub amf_file_open {
  my $file=shift;
  my $fh = new IO::File;
  $fh->open("< $file");
  $fh->binmode(':utf8');
  my $away=<$fh>;
  return $fh;
}


## integrates a whole directory
sub integrate_dir {
  my $ap_dir=shift;
  my $tmp_dir=shift;
  my $debug=shift;
  if($debug) {
    print "finding in $tmp_dir...\n";
  }
  foreach my $full_file (`find $tmp_dir`) {
    chomp $full_file;
    if(-d $full_file) {
      next;
    }
    my $file=$full_file;
    if($debug) {
      print "file is $full_file";
    }
    $file=~s|^\Q$tmp_dir\E/*||;
    if($debug) {
      print "file $file\n";
    }
    my $ap_file="$ap_dir/$file";
    if($debug) {
      if(not -f $ap_file) {      
        print "no such file $ap_file\n";
      }
      else {
        print "found file $ap_file\n";
      }
    }
    &integrate_file("$ap_dir/$file","$tmp_dir/$file"); 
  }
}



## makes an AMF text from a perl structure
sub make_amf_text {
  my $t=shift;
  my $text_element=XML::LibXML::Element->new('text');
  $text_element->setAttribute('id',$t->{'id'});
  foreach my $field ('title','displaypage') {
    if(not defined($t->{$field})) {
      next;
    }
    $text_element->appendTextChild($field,$t->{$field});
  }
  my $hasauthor_element=XML::LibXML::Element->new('hasauthor');
  foreach my $name (@{$t->{authors}}) {
    my $person_element=XML::LibXML::Element->new('person');
    $person_element->appendTextChild('name',$name);
    $hasauthor_element->appendChild($person_element);
  }
  $text_element->appendChild($hasauthor_element);
  return $text_element;
}

## create file from a number
sub number_to_file_with_date {
  my $number=shift;
  my $date=shift;
  my $tmp_dir=shift;
  my $dir="$tmp_dir/$date";
  if(not -d $dir) {
    mkpath($dir);
  }
  ## wrong function call
  my $file_number=create_file_number($number,3);
  my $file="$dir/$file_number.amf.xml";
  my $fh = new IO::File;
  $fh->open(">> $file");
  $fh->binmode(":utf8:");
  return $fh;
}


## create file from a number
sub number_to_file {
  my $number=shift;
  my $digits=shift;
  my $remainder=shift;
  my $tmp_dir=shift;
  my $debug;
  my $file_number=&create_file_number($number,$remainder,$digits);
  my $file;
  ## add directory seperator
  my $count=0;
  while($count < length($file_number)) {
    my $char=substr($file_number,$count,1);
    $file=$file.$char;
    if(not (($count+1) % 3)) {
      $file.='/';
    }
    $count++;
  }
  $file=~s|/$||;
  $file="$tmp_dir/$file";
  my $dir=dirname($file);
  if(not -d $dir) {
    mkpath($dir);
  }
  $file="$file.amf.xml";
  if($debug) {
    print "file is $file\n";
  }
  my $fh = new IO::File;
  $fh->open(">> $file") or die;
  $fh->binmode(":utf8:");
  return $fh;
}


## creates a file number from the end a number
sub create_file_number {
  my $in=shift;
  my $remainder=shift;
  my $digits=shift;
  my $decimals=10**($remainder);
  ## reduce number to cut of $remainder digits
  my $number=($in - ($in % $decimals)) / $decimals; 
  ## add zeros to remainder at the start
  while(length($number)<$digits) {
    $number='0'.$number;
  }
  return $number;
}



# clears files for series that don't exist anymore
sub clear_destination_files {
  my $tmp_dir=shift;
  my $out_dir=shift;  
  my $debug=0;
  if($debug) {
    print "finding in $out_dir\n";
  }
  ## clear files
  open(F,"find $out_dir |");
  my $out_file;
  while($out_file=<F>) {
    chomp $out_file;
    if($debug) {
      print "outfile: $out_file\n";
    }    
    if(-f $out_file) {
      my $in_file=$out_file;
      $in_file=~s|^\Q$out_dir\E|$tmp_dir|;
      if(not -f $in_file) {
        if($debug) {
          print "I have to remove $out_file\n";
        }
        unlink $out_file;
      }      
    }
    if(-d $out_file) {
      rmdir $out_file;
    }
  }
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


## gets root element from file
sub get_document_from_file {
  my $in_file=shift;
  if(not $in_file) {
    warn "no such file: $in_file\n";
    return undef;
  }
  my $fh;
  open $fh, $in_file;
  binmode $fh; # drop all PerlIO layers possibly created by a use open pragma 
  my $doc = $parser->parse_fh($fh);
  close $fh;
  return $doc;
}




## a faster (?) alternative to save_diff_xml
sub save_diff_xml_string {
  my $xml=shift;
  my $out_file=shift;
  my $out_xml_string='';
  my $verbose=0;
  if(-f $out_file) {
    my $out_xml=XML::LibXML->load_xml(location=>$out_file);
    $out_xml_string=$out_xml->toString;
  }
  else {
    if($verbose) {
      print "new file $out_file\n";
    }
    $xml->toFile($out_file);
    return;
  }    
  my $xml_string=$xml->toString;
  if($xml_string eq $out_xml_string) {
    if($verbose) {
      print "no change for $out_file\n";
    }
    return;
  }
  if($verbose) {
    print "new file $out_file\n";
  }
  $xml->toFile($out_file);
}


## creates the AMF element for a document
sub create_amf_element {
  my $doc=shift;
  my $amf_element=$doc->createElement('amf');
  $amf_element->setAttribute('xmlns','http://amf.openlib.org');
  $amf_element->setAttribute('xmlns:html','http://www.w3.org/1999/xhtml');
  $amf_element->setAttribute('xmlns:we','http://whoarewe.3lib.org');
  $amf_element->setAttribute('xmlns:acis','http://acis.openlib.org');
  $amf_element->setAttribute('xmlns:xsi','http://www.w3.org/2001/XMLSchema-instance');
  $amf_element->setAttribute('xsi:schemaLocation','http://amf.openlib.org http://amf.openlib.org/2001/amf.xsd');
  return $amf_element;
}

sub json_store {
  my $data=shift;
  my $file=shift;
  my $file_fh=new IO::File "> $file" or die;
#  my $data_packed=Data::MessagePack->pack($data);
  my $data_packed=encode_json($data);

  print $file_fh $data_packed;
  $file_fh->close;
}

# Deprecated, use json_store
# moved to AuthorProfile::Common
#sub mp_store {
#  my $data=shift;
#  my $file=shift;
#  my $file_fh=new IO::File "> $file" or die $file;
##  my $data_packed=Data::MessagePack->pack($data);
#  my $data_packed=encode_json($data);#
#
#  print $file_fh $data_packed;
#  $file_fh->close;
#}

#sub json_retrieve {
#  my $file=shift;
#  my $data_packed=read_file($file);
##  my $data=Data::MessagePack->unpack($data_packed);
#  my $data=decode_json($data_packed);#
#
#  return $data;
#}
#
# Deprecated, use json_retrieve
#
## canonical AMF reader, read amf file of line structure
#sub amf_file_open {
#  my $file=shift;
#  my $fh = new IO::File;
#  $fh->open("< $file");
#  $fh->binmode(':utf8');
#  my $away=<$fh>;
#  return $fh;
#}
#
#sub mp_retrieve {
#  my $file=shift;
#  my $data_packed=read_file($file);
##  my $data=Data::MessagePack->unpack($data_packed);
#  my $data=decode_json($data_packed);
#
#  return $data;
#}

