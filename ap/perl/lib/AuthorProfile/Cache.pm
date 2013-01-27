package AuthorProfile::Cache;

use base 'CGI::Application';
use lib qw( /home/aupro/ap/perl/lib );
use CGI::Fast;
use Carp::Assert;
use Data::Dumper;
use AuthorProfile::Auvert qw( authorname_to_filename 
                              normalize_name );
use AuthorProfile::Common qw( json_store
                              json_retrieve ); 
use AuthorProfile::Network qw(insert_vert_data_xml);
use XML::LibXML;
use XML::LibXSLT;
use strict;
use Encode;
use utf8;
use open ':utf8';
use encoding 'utf8';

use BerkeleyDB;

#use threads;
#use threads::shared;

# Global variables

## the directories and files
my $home_dir='/home/aupro';
my $ap_dir="$home_dir/ap/amf/auverted";
## log to /var/tmp as long as we don't suexec
my $log_dir="$home_dir/ap/var/log";
my $auma_json_file="$home_dir/ap/var/auma.json";
my $vema_db_file="$home_dir/ap/var/vema.db";


## the stylesheet etc
my $stylesheet;
my $parser;

## other constants

my $amf_ns='http://amf.openlib.org';

## initalize stylesheet
my $xslt = XML::LibXSLT->new();
$parser = XML::LibXML->new();
my $out_style_doc = XML::LibXML->load_xml(location=>"$home_dir/ap/style/aunex.xslt.xml", no_cdata=>1,no_blanks=>1);
my $out_stylesheet = $xslt->parse_stylesheet($out_style_doc);
my $error_style_doc = XML::LibXML->load_xml(location=>"$home_dir/ap/style/error.xslt.xml", no_cdata=>1,no_blanks=>1);
my $error_stylesheet = $xslt->parse_stylesheet($error_style_doc);

## initialize auma
my $auma;

my $vema_db_errors=undef;

my $g_vema_db_dir='/home/aupro/ap/var';
#my $g_vema_db_file='vema.db';

my $g_vema_db_file='/home/aupro/ap/var/vema.db';

my $g_debug=0;

## record potential problems with the vema file
if($g_debug) {
  if(not -d $g_vema_db_dir) { 
    $vema_db_errors.="<div>Debug: vema database directory doesn't exist!</div>"; 
  }
  if(not -f $g_vema_db_file) { 
    $vema_db_errors.="<div>Debug: vema database file doesn't exist!</div>"; 
  }
}

my $g_vema_db;

eval { $g_vema_db = new BerkeleyDB::Hash
  -Filename => $g_vema_db_file,
  -Flags    => DB_RDONLY ;
     };
if($BerkeleyDB::Error) {
  $vema_db_errors.="<div>BDB Error: '$BerkeleyDB::Error'</div>";
}
if($@) { 
  $vema_db_errors.=$!;
}

#########################################




# 01/07/11 - James: The cache for storing dynamically generated and dynamically parsed XHTML from the links on the current XHTML page being viewed.

my $cache={};
#share($cache);
my $cachetime={};
#share($cache);

my $aunex;

my $caching_thr=undef;
my $check_cache_thr=undef;


## setup() can even be skipped for common cases. See CGI::Application doc
sub setup {
  my $self = shift;

  $self->start_mode('mode1');
  #$self->mode_param('rm');

  $self->run_modes(
                   'mode1' => 'show',
                  );

  $self->param('cache' => $cache);
}

sub start_caching {
  &generate_cache();
  return 0;
}

sub check_cache {
  &check_cachetime(time());
  return 0;
}

## shows profile
sub show { 
  my $self = shift;  

# Disabled due to a segmentation fault that occurs with multithreaded implementations of key features of the application due to a conflict with the CGI::Fast module.

#  $caching_thr=threads->create({'scalar' => 1}, \&start_caching);
#  $caching_thr->detach();
#  $check_cache_thr=threads->create({'scalar' => 1}, \&check_cache);
#  $check_cache_thr->detach();

  ## Get CGI query object
  my $q = $self->query();
  ## create the canonical location
  $aunex = decode_utf8($q->param('q'));  

  if(not $aunex) {
    return &fatal_error($self,"aunex \"$aunex\" could not be decoded") ;
  }


  ## 
  if(not defined($auma)) {
    $auma=&AuthorProfile::Common::json_retrieve($auma_json_file);
  }

#  my $canonical_location="http://wotan.liu.edu/author/profile.fcgi?q=$aunex";
  my $canonical_location="http://dev.authorprofile.org/=$aunex";

  # my $canonical_location="http://wotan.liu.edu/AuthorProfile/$aunex";
  ## method from cgi::application to create or change headers
  $self->header_add(-type => 'text/html',
                    -status => '201 Created',
                    -location => $canonical_location,
                    -charset => 'utf-8');

  # 01/09/11 - James: Obtain the $cache
  $cache=$self->param('cache');

  my $output = '';

  my $normal_name = &normalize_name($aunex);
  if(not $normal_name) {
    return &fatal_error($self,"aunex \"$aunex\" could not be normalized") ;
  }

  # If the previously generated XHTML has been passed in the cache...
  if(defined($cache->{$normal_name})) {
    # ...then there is no need to go any further.
    $output=$cache->{$normal_name};
    # For debugging purposes
    $output.="Retrieved from the \$cache structure.\n" if $g_debug;

    return $output;
  }
  
  ## should be changed later
  my $file_name .= &authorname_to_filename($normal_name,'silent');
  my $amf_file = "$ap_dir/$file_name";
  if(not -f $amf_file) {
    return &fatal_error($self,"no such file: '$amf_file' for aunex \"$aunex\" normalized \"$normal_name\"") ;
  }

  my $dom = eval { $parser->parse_file($amf_file);};
  if($@) {
    return &fatal_error($self,$@);
  }

  ## changes $dom to add leavout attribute
  ## for the author, thus avoiding linking the
  ## page to itself

  my $document_element=$dom->documentElement;
  $document_element=&AuthorProfile::Common::add_status($document_element,$auma,$aunex);

#  return "$g_vema_db";

  my $errors=$vema_db_errors;  
  $document_element=&insert_vert_data_xml($dom, $g_vema_db, $normal_name,\$errors,$g_debug);

  my $results = eval { 
    $out_stylesheet->transform($dom, 'aunex' => "'$aunex'") ;
  };
  if($@) {
    return &fatal_error($self,$@);
  }

  ## bytes, not utf-8 string, cgi::fast wants it this way
  $output=$out_stylesheet->output_as_bytes($results);

  # Message for vema.db access errors:
  if($errors and $g_debug) {
    $dom = $parser->parse_string($output);
    $document_element=$dom->documentElement;
    my $body_elem=$document_element->getChildrenByTagName('body')->[0];
    my $vema_error_elem=$body_elem->appendChild($dom->createElement('div'));
    $vema_error_elem->setAttribute('class','vema_error');
    $vema_error_elem=$vema_error_elem->appendChild($dom->createElement('p'));
    $vema_error_elem->appendText($errors);
    return $dom->toString(1);
  }

  return $output;
}


# Should be interrupted if another query comes along...

sub teardown {
  my $self=shift;
  my $output=shift;
  # For debugging purposes
#  $$output.= $aunex;
#  $cache=&refresh_cache;
  return 0;
}

sub refresh_cache {
  $cache=&generate_cache();
  $cachetime=&check_cachetime(time());
  return 0;
}

sub check_cachetime {
  my $time=shift;
  foreach my $cache_time (keys %{$cachetime}) {
    if(($time - $cache_time) >= 900) {
      &clear_cache_values_for_time($cache_time);
    }
  }
  return $cachetime;
}

sub clear_cache_values_for_time {
  my $time=shift;
  foreach my $aun (@{$cachetime->{$time}}) {
    delete $cache->{$aun};
    delete $cachetime->{$time};
  }
  return;
}

sub generate_cache {
  if(not defined($aunex)) {
      return $cache->{'error'}='undefined aunex';
  }
  my $normal_name = &normalize_name($aunex);
  if(not $normal_name) {
    return $cache->{'error'}='normal_name';
  }
  my $file_name .= &authorname_to_filename($normal_name,'silent');
  my $amf_file = "$ap_dir/$file_name";
  if(not -f $amf_file) {
    return $cache->{'error'}='amf_file';
  }
  my $dom = eval { $parser->parse_file($amf_file);};
  if($@) {
    return $cache->{'error'}="parse_file: $@";
  }

  ## Restructure: Place into a separate function...
  my $document_element=$dom->documentElement;
  $document_element=&AuthorProfile::Common::add_status($document_element,$auma);
  my $XSLT_results = eval { $out_stylesheet->transform($dom, 'aunex' => "'$aunex'") };
  if($@) {
    return 1;
  }
  ## bytes, not utf-8 string, cgi::fast wants it this way
  my $dyn_XHTML=$out_stylesheet->output_as_bytes($XSLT_results);
  
  # 01/08/11 - James
  # Obtain all of the <name/> elements in from the XML.
  my @name_elems=$document_element->getElementsByTagName('name');
  
  # Generate the $cache through cycling through each <name/> element.
  # The $cache is structured as follows:
  
  # 01/09/11 - James
  
  # $cache->{[aunex]}=[XHTML]
  # $cachetime->{[time]}=[aunexes]

  foreach my $name_elem (@name_elems) {
    my $name_status=$name_elem->getAttribute('status');
    if(not defined($name_status)) { return $cache->{'error'}='status'; }
    my $name=$name_elem->textContent();
    my $norm_name=&normalize_name($name);

    if(not defined($name)) { return $cache->{'error'}='textContent'; }
    # Replace with a filename test - easier than going through the statuses...
    if(defined($name_status)) {
      if($name_status eq '0') {
        if(defined($cache->{$name})) {
          next;
        }
        $cache->{$norm_name}=gen_dyn_XHTML($name);
        push(@{$cachetime->{time()}},$norm_name);
      }
    }
  }
  return $cache;
}

sub gen_dyn_XHTML {

  #Restructure into a single function

  my $name=shift;

  if(not defined($name)) { return 'error'; }

  my $normal_name=&normalize_name($name);
  my $file_name .= &authorname_to_filename($normal_name,'silent');
  my $amf_file = "$ap_dir/$file_name";
#  return $amf_file;
  if(not -f $amf_file) {
    return 'amf_file';
  }
  my $dom = eval { $parser->parse_file($amf_file);};
  if($@) {
    warn "count not parse $amf_file: $@";
    return 'parse_file';
  }

  my $document_element=$dom->documentElement;
  $document_element=&AuthorProfile::Common::add_status($document_element,$auma);
#  return $document_element->toString(1);

  my $XSLT_results = eval { $out_stylesheet->transform($dom, 'aunex' => "'$name'") };
  if($@) {
    return 1;
  }
  ## bytes, not utf-8 string, cgi::fast wants it this way
  my $dyn_XHTML=$out_stylesheet->output_as_bytes($XSLT_results);

  #return $dyn_XHTML;
}

## fatal_error
sub fatal_error {
  my $self = shift;  
  my $error =shift;
  my $dom = XML::LibXML::Document->new('1.0','utf-8');
  my $error_element=$dom->createElement('error');
  $error_element->appendTextChild('message',$error);
  $error_element->appendTextChild('query_object',Dumper($self));
  $dom->setDocumentElement($error_element);
  my $results = eval { $error_stylesheet->transform($dom); };
  if($@) {
    return &fatal_error($self,$@);
  }
  ## bytes, not utf-8 string, cgi::fast wants it this way
  my $output=$out_stylesheet->output_as_bytes($results);
  return $output;
}


sub log_me {
  my $in=shift;
  my $date=`date -I`;
  chomp $date;
  my $log_file="$log_dir/author_profile_$date.log";
  open(L, ">>:encoding(UTF-8)", "$log_file");
  $|=1;
  print L $in, "\n";
  close L;
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


## cheers!
1;
