#0;136;0c
package AuthorProfile::Auvert;

=head1 NAME

AuthorProfile::Auvert 

=cut

require Exporter;

use strict;
use warnings;
use File::Basename;
use File::Path;
use File::Temp qw/ tempfile tempdir /;
use File::stat;
use lib qw( /home/aupro/ap/perl/lib /home/aupro/usr/lib/perl );

use Unicode::String qw(utf8 latin1 utf16be uhex);
use Data::Dumper;
use Storable qw(nfreeze thaw);

use BerkeleyDB;
use AuthorProfile::Conf;

use vars qw(%file_times); 

use Mamf::Common qw(
                     amf_file_open 
                     id_to_ref
                     integrate_dir
                     make_amf_from_handle_hash
                     get_from_db_mp
                     put_in_db_mp
                     get_from_db_json
                     put_in_db_json
                     file_to_handle_hash 
                     print_value
                  );

use AuthorProfile::Common qw(
                              put_in_mongodb
                              get_from_mongodb
                              getMongoDBAuProRecord
                              updateMongoDBRecord
                           );

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
                     auvert_file
                     auvert_dir
                     process_in_file_time_start
                     process_in_file_time_end
                     auvert_file_life                    
                     authorname_to_filename 
                     normalize_name
                     mark_all_files_as_processed
                     get_auversion_collec_name
                     fileAuvertFile
                  );
my $verbose=1;
my $debug=0;
my $do_delete_tmp=1;

## checks if a file needs doing
sub process_in_file_time_start {
  ## full file name expecetde here
  my $file=shift;

  my $collec=shift;
  # 01/23/12 - James
  # Deprecated in favor of MongoDB
  ## the db for in files
#  my $db=shift;

  #Added for the "forced" option...
  my $forced=shift;

  my $debug=0;
  if(not -f $file) {
    return -1;
  }
  ## look at files only relative to the main dire
  my $file_name=$file;
  my $db_key=file_name_to_db_key($file_name);
  my $file_stat = stat($file);
  my $file_mtime=$file_stat->mtime;
  if($debug) {
    print "file_mtime is $file_mtime\n";
  }
  ## get existing file data

  # Only dealing with XML for now...
  my @results=AuthorProfile::Common::get_from_mongodb($collec,{'amf-xml' => $db_key});
  my $file_data=pop @results;
  my $file_data_with_key->{$db_key}=$file_data;
  #Added for the "forced" option...
  if(not $forced) {
    if($debug) {
      print("Not forced...\n");
    }
    my $reason=&determine_if_file_needs_processing($file_mtime,$file_data,$file_name);

    return $file_data_with_key if $reason;

  }
  else {
    print "Forced...\n" if $debug;
  }
  ## file needs procesing, set the start tie

  # Unless I explicitly undef $file_data, I receive the following error:
  #     # Can't use string ("0") as a HASH ref while "strict refs" in use at /home/aupro/ap/perl/lib/AuthorProfile/Auvert.pm line 130.
  # I have attempted initializing $file_data with:
  #     # my $file_data={};
  # This did not resolve the problem.
  undef $file_data if not $file_data;
  $file_data->{'start'}=time();
  if($debug) {
    print "putting into db for $file_name ".Dumper $file_data;
  }

  AuthorProfile::Common::put_in_mongodb($collec,$file_data,'amf-xml',$db_key);

  return $file_data_with_key;
}

sub process_in_file_time_end {
  ## full file name expecetde here
  my $file_data_with_key=shift;

  die $file_data_with_key;
  ## the db for in files
#  my $db=shift;

  my $collec=shift;
  ## there is only one key, maybe this could 
  ## be done quicker

  my @file_names=keys %{$file_data_with_key};
  my $file_name=$file_names[0];
#  print("This is the key: $file_name\n\n");
  my $file_data=$file_data_with_key->{$file_name};

  my $time=time();
  $file_data->{'end'}=$time;

  my @results=AuthorProfile::Common::put_in_mongodb($collec,$file_data,'amf-xml',$file_name);
  my $result=pop @results;

  return $result;
}

## finds if a file needs processing
sub determine_if_file_needs_processing {
  my $mtime=shift;
  my $file_data=shift;
  my $file_name=shift;
  my $verbose=1;

  ## return a reason
  if((not $file_data)) {
    return "no prior record for $file_name";
  }
  if(not $file_data->{'start'}) {
    return "no file start time for $file_name";
  }
  if(not $file_data->{'end'}) {
    return "no file end time for $file_name";
  }
  if($file_data->{'start'} > $file_data->{'end'}) { 
    return "start time after end time for $file_name";
  }
  if($mtime > $file_data->{'start'}) {
    return "file $file_name is more recent than last start of processing\n";
  }
  ## otherwsie don't process the file
  return 0;
}


## marks all the files as having being processed
sub mark_all_files_as_processed {
  ## the db 
  my $db=shift;
  my $file_names=shift; 
  if(not defined($db)) {
    return;
  }
  ## hash of files
  my $time=time();
  foreach my $file_name (keys %{$file_names}) {
    if($debug) {
      print "marking file $file_name as processed\n";
    }
    my $db_key=&file_name_to_db_key($file_name);
    my $file_data=&get_from_db($db,$db_key);
    
    ## set start and end to current time to signal file is processed
    print "got file_data: " . print_value($file_data);
    my $time=time;
    $file_data->{'end'}=$time;
    print "\nmarking $file_name as processed\n";
    print print_value($file_data), "\n";
    &put_in_db($db,$db_key,$file_data);
    if($debug) {
      my $current_file_data=&get_from_db($db,$db_key);
      print "new current value" . Dumper $current_file_data;
    }
  }
}

# Currently only implemented for 3lib collections
sub get_auversion_collec_name {
  my $file_name=shift;
  my $collec_name=$file_name;
  $collec_name=~s|^\Q$threelib_dir\E/*||;
  $collec_name=~s|\.amf\.xml$||;
  $collec_name=~s|/.*$||;
  return $collec_name;
}

sub file_name_to_db_key {
  my $file_name=shift;
  my $db_key=$file_name;
  $db_key=~s|^\Q$threelib_dir\E/*||;
  $db_key=~s|\.amf\.xml$||;
  while($db_key=~m|.*/.*|) {
    # Remove the collection name
    $db_key=~s|^.*/||;
  }
#  $db_key=~s|^\Q$relative_input_dir\E/*||;
  return $db_key;
}

# 01/07/12 - James
# Usage:
#     updateFileAuversionRecord [HASH query hash] [SCALAR file path] [HASH script]
sub updateAuversionRecord {

  # 01/07/12 Common error:
  # updateMongoDBRecord failed for [...] in authorprofile.auversion after 5 attempts: Operation now in progress
  # This is only resolved by passing {"safe" => 1}

  return AuthorProfile::Common::updateMongoDBRecord('authorprofile','auversion',$_[0],$_[1],{"upsert" => 1,"multiple" => 0,"safe" => 1}) or die "Fatal: Could not update the auversion record for $_[0]: $!";
}



# 01/07/12 - James
# Usage:
#     fileAuvertFile [SCALAR AMF file path], [SCALAR AMF collection name]
# Used in:
#     &process_dir of 'fileAuvertCollection.pl'
# Based upon auvert_file_life
sub fileAuvertFile {
  my $in_file=shift;
  my $amfColl=shift;
  # Fix
  my $VERBOSE=1;

  if(not -f $in_file) {
    warn "No such file: $in_file\n" if $VERBOSE;
    return;
  }
  my $fh=amf_file_open($in_file);
  my $filePath=$in_file;

  # Fix - too tired
  my $input_dir="$home_dir/ap/amf/3lib/";

  $filePath=~s/$input_dir//;

  # Deprecated
  # 02/16/12 - James
  # Check if the file has already been successfully auverted.
  #my @records=AuthorProfile::Common::getMongoDBAuProRecord('auversion',undef,{'filePath' => $filePath,'lastAuversionSuccessful' => 1});
  #my $cursor=AuthorProfile::Common::getMongoDBAuProRecord('auversion',undef,{'filePath' => $filePath,'lastAuversionSuccessful' => 1});
  #my @records=$cursor->next;
  #if(@records) {
    #print "$filePath was already auverted at ".%{pop @records}->{'timeLastAuverted'}."\n";
    #print "$filePath was already auverted";
    #return;
  #}

  # Update the "auversion" record after the file has been opened for reading.
  updateAuversionRecord({'filePath' => $filePath},{'$set' => {'timeLastAuverted' => time,'lastAuversionSuccessful' => 0,'amfCollection' => $amfColl}});
  my $line;
  ## find name of $in_file, i.e, from input_dir
  my $in_file_name=$in_file;
  $in_file_name=~s|^\Q$ap_dir\E||;
  ## remove .amf.xml, to avoid having it in the comment
  $in_file_name=~s|\.amf\.xml$||;
  while($line=<$fh>) {
    ## a really primitive check for the last line
    if($line=~m|^</amf>|) {
      undef $line;
      ## closes file
      undef $fh;
      last;
    }
    my $dom = XML::LibXML->load_xml(string => $line);
    my $text_element=$dom->documentElement();    
    ## change id= to ref=
    $text_element=&id_to_ref($text_element);
    my @author_names = $text_element->findnodes('/text/hasauthor/person/name/text()');
    my $count_author=0;
    foreach my $author_name (@author_names) {
      $count_author++;
      print "Inserting/Updating auversion record for ",$author_name->toString,"\n" if $VERBOSE;

      #Repairing the problem of 'opt/amf/3lib/' in elis and solis collection records
      $in_file_name=~s|opt\/amf\/3lib\/||;

      &auvert_author_life($author_name,$text_element,
                          ## the remaining arguments are put into the comment. 
                          $in_file_name,$count_author,time());
      # updateAuthorAuversionRecord({'aunex' => $author_name},{'$set' => {'timeLastUpdated' => time}});
    }
  }
  # Update the auversion record after the file has been successfully "auverted"
  updateAuversionRecord({'filePath' => $filePath},{'$set' => {'lastAuversionSuccessful' => 1}});
}


## auverts a file to a temporary file
## only for line amf! 
sub auvert_file_life {
  my $in_file=shift;
  my $debug=0;
  if($debug) {
    print "starting to auvert\n";
  }
  if(not $in_file) {
#    print "no file\n";
    return 0;
  }
  if(not -f $in_file) {
#    print "error: no such file: $in_file\n";
    return 0;
  }
  my $fh=amf_file_open($in_file);
  my $line;
  ## find name of $in_file, i.e, from input_dir
  my $in_file_name=$in_file;
  $in_file_name=~s|^\Q$ap_dir\E||;
  ## remove .amf.xml, to avoid having it in the comment
  $in_file_name=~s|\.amf\.xml$||;
  while($line=<$fh>) {
    ## a really primitive check for the last line
    #print "line is $line\n";
    if($line=~m|^</amf>|) {
      undef $line;
      ## closes file
      undef $fh;
      last;
    }
    my $dom = XML::LibXML->load_xml(string => $line);
    my $text_element=$dom->documentElement();    
    ## change id= to ref=
    $text_element=&id_to_ref($text_element);
    #print $text_element->toString, "\n";
    my @author_names = $text_element->findnodes('/text/hasauthor/person/name/text()');
    my $count_author=0;
    foreach my $author_name (@author_names) {
      $count_author++;
      if($debug) {
        print "doing ". $author_name->toString, "\n";
      }

      #Repairing the problem of 'opt/amf/3lib/' in elis and solis collection records
      $in_file_name=~s|opt\/amf\/3lib\/||;

      &auvert_author_life($author_name,$text_element,
                          ## the remaining arguments are put into the comment. 
                          $in_file_name,$count_author,time());
    }
  }
}


## auverts a single author
sub auvert_author_life {
  my $author=shift;
  my $aunex=$author->toString(0);
  my $text_element=shift;
  # Fix
  my $VERBOSE=1;

  my $ref=$text_element->getAttribute('ref');
  ## remaining arguments
  my @comments=@_;
  my $comment=&compile_comments(@comments);
  my $name=&normalize_name($aunex);
  # print "name is $name, finding out_file\n";
  my $out_file=&authorname_to_filename($name);
  updateAuversionRecord({'aunex' => $aunex},{'$set' => {'filePath' => $out_file,'lastUpdateSuccessful' => 0,'timeLastUpdated' => time}});
  if(not defined($out_file)) {
    warn "Fatal: Could not generate the auversion file path for $aunex" if $VERBOSE;
    return;
  }
  my $text_element_string=$text_element->toString(0)." $comment\n";
  if(-f "$auvert_dir/$out_file") {
    
    &inject_text($text_element_string,$ref,"$auvert_dir/$out_file");
  }
  else {
    &create_ap_file($text_element_string,$ref,"$auvert_dir/$out_file");
  }
  updateAuversionRecord({'aunex' => $aunex},{'$set' => {'lastUpdateSuccessful' => 1}});
}

sub remove_comment_part_of_text_string {
  my $in=shift;
  ## the regex here prohibits a comment in the contents
  $in=~s| *<!--[^-]*-->\n$|\n|;
  return $in;
}



sub inject_text {
  my $text_element_string=shift;
  my $handle=shift;
  my $out_file=shift;
  my $debug=0;
  ## this functions returns empty when it can not
  ## determine a file
  if(not defined($out_file)) {
    if($debug) {
      print "no outfile in auvert_author\n";
    }
    return;
  }
  my $handle_hash=&file_to_handle_hash($out_file);
  #  print("This is the handle_hash:", Dumper $handle_hash, "\n");
  my $text_already_there=$handle_hash->{$handle};
  if(defined($text_already_there)) {
    #    print("This is text_already_there: ", $text_already_there, "\n");
    ## check if the text has changed
    $text_already_there=&remove_comment_part_of_text_string($text_already_there);
    $text_element_string=&remove_comment_part_of_text_string($text_element_string);
    if($text_already_there eq $text_element_string) {
      ## fixme: update time in a database when
      ## this has been seen
      # print "unchanged: $handle\n";
      return;
    }
  }
  $handle_hash->{$handle}=$text_element_string;
  my $amf_doc=&make_amf_from_handle_hash($handle_hash);
  &save_string_in_file($amf_doc,$out_file);
}

## writes string into file
## don't comment out the print ;-)
sub save_string_in_file {
  my $string=shift;
  my $file=shift;
  my $fh = new IO::File;
  $fh->open("> $file");
  $fh->binmode(':utf8:');
  if(not $string=~m|\n$|) {
    $string="$string\n";
  }
  print $fh $string;
  $fh->close;
}

## creates an amf file from 
sub create_ap_file {
  my $text_element_string=shift;
  my $handle=shift;
  my $out_file=shift;
  my $dir=dirname($out_file);
  if(not -d $dir) {
    mkpath $dir;
  }
  my $handle_hash;
  $handle_hash->{$handle}=$text_element_string;
  my $amf_doc=&make_amf_from_handle_hash($handle_hash);
  &save_string_in_file($amf_doc,$out_file);
}


## puts the comments together
sub compile_comments {
  my @comments=@_;
  #print Dumper @comments;
  my $comment=join(' ',@comments);
  $comment="<!-- $comment -->";
  return $comment;
}


## converts author name to file name
sub authorname_to_filename {
  my $in=shift;
  my $debug=shift;
  my $out='';
  my $count=0;
  ## the humannames module may annul the 
  ## input if it has not at least three chars
  if(not defined($in) or not $in) {
    return undef;
  }
  ## normalize name
  eval { $in=&normalize_name($in); };
  if($@) {
    warn("authorname_to_filename: FATAL ERROR: Could not normalize \$in - $!\n");
    exit;
  }
  if(not defined($in) or not $in) {
    return undef;
  }
  ## sanity checks
  if($in=~m|_|) {
    if(not $debug) {
      print "name '$in' not converted, prohibited char: _\n";
    }
    return undef;
  }

  if($in=~m|/|) {
    if(not $debug) {
      print "name '$in' not converted, prohibited char: /\n";
    }
    return undef;
  }

  if($in=~m|\d|) {
    if(not $debug) {
      print "name '$in' not converted, contains one or more digits\n";
    }
    return undef;
  }

  ## go through every character
  my $count_position=0;
  my $count_increment=0;
  my $count_last_slash=0;
  my $count_step=0;
  my $count_times_step_was_used=0;
  while($count_position < length($in)) {
    ## current char
    my $char.=substr($in,$count_position,1);
    ## returns code position
    my $position=ord($char);
    if($position<127) {
      $out=$out.$char;
    }
    elsif($position>65535) {
      # print "name $in not converted, char $char out of BMP\n";
      return undef;
    }
    else {
      my $u=utf8($char);
      ## hex codepoint
      my $hex=$u->uhex;
      $hex=~s|\QU+\E||;
      ## use uppercase so that hex chars are distinguised from 
      ## other characters a-e
      $hex=uc($hex);
      $out=$out.$hex;
    }
    ## add directory separator
    if($count_position-$count_last_slash==$count_step) {
      $out.='/';
      $count_last_slash=$count_position+1;
      if($count_times_step_was_used==$count_step) {
        $count_step++;
        $count_times_step_was_used=0;
      } 
      else {
        $count_times_step_was_used++;
      }
    }
    $count_position++;
  }
  $out=~s|/$||g;
  $out=~s| |_|g;
  $out.='.amf.xml';
  return $out;
}

sub dir_separator_add {
  my $in=shift;
  my $count=shift;

  my $strlen=length ($in);

  return 0;  
}


## normalize name
sub normalize_name {
  my $in=shift;
  ## translate name to lowercase
  $in = lc $in;
  ## change single quote to curly one
  $in=~s/'/\x{2019}/g;
  ## change non-word (word is alphanumeric and _) to space,
  ## avoids dealing with punctuation
  $in=~s/\W/ /g;
  ## strip starting and training whitespace
  $in=~s/(^\s+|\s+$)//g;
  ## collapse whitespace
  $in=~s/\s+/ /g;
  ## minimum 3 useful signs:
  if ( $in=~s/(\w)/$1/g < 3 ) { 
    undef $in; 
  }
  return $in; 
}





## normalize name
sub normalize_name_ivan {
  my $in=shift;
  ## translate name to lowercase
  $in = lc $in;
  ## remove single quote, which happens in names like "O'Brien" and "Vasil'ev"
  $in=~s/'//g;
  ## from http://ahinea.com/en/tech/accented-translate.html
  ##  treat characters ä ñ ö ü ÿ
  $in=~s/\xe4/ae/g;
  $in=~s/\xf1/ny/g;
  $in=~s/\xf6/oe/g;
  $in=~s/\xfc/ue/g;
  $in=~s/\xff/yu/g;

  ##  decompose
  $in = NFD( $in );
  ##  strip combining characters
  $in=~s/\pM//g;

  $in=~s/\x{00df}/ss/g;  ##  German sz
  $in=~s/\x{00c6}/AE/g;  ##
  $in=~s/\x{00e6}/ae/g;  ##
  $in=~s/\x{0132}/IJ/g;  ##
  $in=~s/\x{0133}/ij/g;  ##
  $in=~s/\x{0152}/Oe/g;  ##
  $in=~s/\x{0153}/oe/g;  ##

  ##
  $in=~tr/\x{00d0}\x{0110}\x{00f0}\x{0111}\x{0126}\x{0127}/DDddHh/; 
  ##
  $in=~tr/\x{0131}\x{0138}\x{013f}\x{0141}\x{0140}\x{0142}/ikLLll/; 
  $in=~tr/\x{014a}\x{0149}\x{014b}\x{00d8}\x{00f8}\x{017f}/NnnOos/; 
  $in=~tr/\x{00de}\x{0166}\x{00fe}\x{0167}/TTtt/;                   

  ## normalize whitespace
  $in=~s/\W/ /g;
  ## strip starting and training whitespace
  $in=~s/(^\s+|\s+$)//g;
  $in=~s/\s+/ /g;
  # minimum 3 useful signs:
  if ( $in=~s/(\w)/$1/g < 3 ) { 
    undef $in; 
  }
  return $in; 
}

## auverts a whole directory of AMF files
sub auvert_dir {
  my $out_dir=shift;
  my $in_dir=shift;
  my $tmp_dir=shift;
  ## infiles_db
  my $db=shift;
  ## set to true if third argument is not a direcotry
  my $debug=0;
  if(not $in_dir) {
#    print "no directory\n";
    return undef;
  }
  if(not -d $in_dir) {
#    print "no such directory: $in_dir\n";
    return undef;
  }
  ## if we don't get a temparory directory, let us create one
  if(not -d $tmp_dir) {
    $tmp_dir = tempdir( CLEANUP => $do_delete_tmp);
  }
  elsif($tmp_dir) {
    $debug=1;
  }
  ## collects files names to be marked as processed
  my $file_names;
  foreach my $file (`find $in_dir`) {   
    chomp $file;
    if($debug) {
      print "file is $file\n";
    }
    if(-d $file) {
      next;
    }
    ## check if files needs processing
    if(not &process_in_file_time($file,$db)) {
#      print "file $file needs no processing\n";
      next;
    }
    ## create file_name, i.e. file without input dir
    my $file_name=$file;
    ## just in case it is there
    $file_name=~s|^\Q$ap_dir\E/*||;
    $file_names->{$file_name}=1;
    ## call auvert file with $tmp_dir, it is already given
    &auvert_file($file,$tmp_dir);
    ###sleep 1;
    ##
  }
  my $file_names_tists=&integrate_dir($out_dir,$tmp_dir,'with files tist');
  ## saving work
  &mark_all_files_as_processed($db,$file_names);  
  return $file_names_tists;
}

## cheers!
1;
