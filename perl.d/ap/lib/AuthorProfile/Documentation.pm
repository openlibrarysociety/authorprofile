package AuthorProfile::Documentation;

use base 'CGI::Application';
use lib qw( /home/aupro/ap/perl/lib);
use strict;
use warnings;

use CGI::Fast;
use Date::Format;
use Data::Dumper;
use Encode;
use File::Listing;
use File::Basename;
use File::Slurp;
use File::Path;
use XML::LibXML;
use XML::LibXSLT;

use AuthorProfile::Conf;
use AuthorProfile::Common;

## a hash of stylesheets
my $xslts;
$xslts->{'directory'}=&AuthorProfile::Common::load_xslt("$xslt_dir/directory.xslt.xml");
$xslts->{'file'}=&AuthorProfile::Common::load_xslt("$xslt_dir/file.xslt.xml");
$xslts->{'error'}=&AuthorProfile::Common::load_xslt("$xslt_dir/error.xslt.xml");

## our dom
my $dom = XML::LibXML::Document->new('1.0','utf-8');

## setup() can even be skipped for common cases. See CGI::Application doc
sub setup {
  my $self = shift;
  $self->start_mode('mode1');
  $self->run_modes('mode1' => 'show');
}

## generate xml file for xslt debugging?
## it can only run on the web if this is set to 0
my $xslt_debug=0;

## shows the contents
sub show { 
  my $self = shift;    
  my $query=$self->query;
  my $target = decode_utf8($query->param('q'));  
  if(not defined($target) or not $target) {
    return &web_error($self,"The target to document, as by the “q” parameter, is empty.");
  }
  ## this changes the global debug variable 
  $xslt_debug = decode_utf8($query->param('xslt_debug'));  
  ## name of target as appears in inteface
  my $name=$target;
  ## the target itself is relative
  $target=~s|^/+||;
  $self->header_props(-type => 'text/html; charset=utf-8');
  ## check for html
  my $plain="$home_ap_dir/$target";
  if($plain=~m|$home_ap_dir/html| 
     and -f $plain 
     and $plain=~m|\.html$|) {
    my $read=&read_file("$plain");
    if(not $read) {
      return &web_error($self,"I can not read the file '$plain'.");
    }
    return &read_file("$plain") ;
  }
  ## check for contents shows as plain text                                     
  if(-f $plain) {
    ## if the target is a png 
    if($plain=~m|\.png$|) {
      $self->header_props(-type => 'image/png');
      my $read=&read_file("$plain");
      if(not $read) {
        return &web_error($self,"I can not read the file '$plain'.");
      }
      return $read;
    }
    ## php for Gina
    if($plain=~m|/php/| or $plain=~m|\.php$|) {
      $self->header_props(-type => 'text/plain');
      my $read=&read_file("$plain");
      if(not $read) {
        return &web_error($self,"I can not read the file '$plain'.");
      }
      return $read;
    }
    return &file_to_html($self,$plain,$name);
  }
  if(-d $plain) {
    return &dir_to_html($self,$plain,$name);
  }
  return &web_error($self,"I can not deal with the targe '$target'.");
}

## make a directory list, and produce html
sub dir_to_html {
  my $self=shift;
  my $dir=shift;
  my $name=shift;
  my $octets;
  $dir=~s|/+$||;
  if(not -d $dir) {
    return &web_error($self,"The directory '$dir' could not be found");
  }
  my $dir_element = $dom->createElement('directory');
  ## name of directory as visible to users
  $name=~s|$home_ap_dir/*$|/|;
  $dir_element->setAttribute('name',$name);
  for (parse_dir(`ls -l $dir/`)) {
    my ($file, $type, $size, $mtime, $mode) = @$_;
    ## emacs backups and autosaves are not shown
    next if $file =~ m|~$|;
    next if $file =~ m|#|;
    ## don't show the opt
    next if $file =~ m|^opt|;
    ## don't show the link to 3lib
    next if $file =~ m|^3lib|;
    ## don't show the amf data, available on the ftp server
    next if $file =~ m|^amf|;
    ## links
    if($type=~m|^l +(.*)|) {
      ## where does it point to 
      my $target=$1;
      my $link=$target;
      $link=~s|/*opt/(.*)/$|$1|;
      $link=~s|/*opt/(.*)$|$1|;
      ## now replace filename with link
      $file=$link;
      ## set the type to d, cheat
      $type='d';      
    }
    my $file_element = $dom->createElement('file');
    ## name of file
    $file_element->setAttribute('name',$file);
    ## link for file
    my $link;
    if($name ne '/') {
      $link="/$name/$file";
    }
    else {
      $link="//$file";
    }
    $file_element->setAttribute('link',"$link");
    $file_element->setAttribute('type',$type);
    $file_element->setAttribute('size',$size);
    $file_element->setAttribute('mtime',time2str("%Y\x{2012}%m\x{2012}%d",$mtime));
    $dir_element->appendChild($file_element);
  } 
  $dom->setDocumentElement($dir_element);
  my $results=$xslts->{'directory'}->transform($dom);  
  ## write out the static debuging files
  if($xslt_debug) { 
    my $xml_file="$xml_dir/directory.xml";
    print "writing $xml_file\n";
    $dom->toFile($xml_file,1);
    my $html_file="$html_dir/tmp/directory.html";
    print "writing $html_file\n";
    $dom->toFile($html_file,1);
    exit;
  }  
  $octets=$xslts->{'directory'}->output_as_bytes($results);
  return $octets;
}

## produce the representation of a file
sub file_to_html {
  my $self=shift;
  my $file=shift;
  my $octets;
  if(not -f $file) {
    return &web_error($self,"I could not find the file '$file'.");
  }
  my $dom = XML::LibXML::Document->new('1.0','utf-8');
  my $file_element = $dom->createElement('file');
  ## name of directory as visible to users
  my $name=$file;
  $name=~s|$home_ap_dir/*||;
  $file_element->setAttribute('name',$name);
  my $text=eval {
    read_file($file);
  };
  if(not $text) {
    return &web_error($self,"I could not read the file '$file': $@.");
  }
  ## remove unestaetic trailing whitespace
  $text=~s|\s+$||;
  $file_element->appendText($text);
  $dom->setDocumentElement($file_element);
  my $results=$xslts->{'file'}->transform($dom);  
  ## write out the static debuging files
  if($xslt_debug) { 
    my $xml_file="$xml_dir/file.xml";
    print "writing $xml_file\n";
    $dom->toFile($xml_file,1);
    my $html_file="$html_dir/tmp/file.html";
    print "writing $html_file\n";
    $dom->toFile($html_file,1);
    exit;
  }    
  $octets=$xslts->{'file'}->output_as_bytes($results);
  return $octets;
}


## error function. a very similar is in Web.pm
## as fatal error
sub web_error {
  my $self = shift;
  my $error=shift;
  my $error_element=$dom->createElement('error');
  $error_element->appendTextChild('message',$error);
  $error_element->appendTextChild('query_object',Dumper($self));
  $dom->setDocumentElement($error_element);
  my $results = eval { 
    $xslts->{'error'}->transform($dom); 
  };
  ## write out the static debuging files
  if($xslt_debug) { 
    my $xml_file="$xml_dir/error.xml";
    print "writing $xml_file\n";
    $dom->toFile($xml_file,1);
    my $html_file="$html_dir/tmp/error.html";
    print "writing $html_file\n";
    $results->toFile($html_file,1);
    exit;
  }    
  my $output=$xslts->{'error'}->output_as_bytes($results);
  return $output;
}

## cheers!
1;
