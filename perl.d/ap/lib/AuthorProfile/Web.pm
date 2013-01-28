package AuthorProfile::Web;

use strict;
use warnings;
use utf8;
use open ':utf8';
use encoding 'utf8';

use base 'CGI::Application';
use lib qw( /home/aupro/ap/perl/lib );
use BerkeleyDB;
use CGI::Fast;
#use CGI::Application::Plugin::Redirect;
use Carp::Assert;
use Data::Dumper;
use File::Slurp;
use AuthorProfile::Auvert qw( authorname_to_filename 
                              normalize_name );
use AuthorProfile::Common qw( json_store
                              json_retrieve 
                              load_xslt
                           ); 

##use Lingua::EN::Numbers qw(num2en num2en_ordinal);
use AuthorProfile::Conf;
use AuthorProfile::Network qw(insert_vert_data_xml
                            insert_horizontal_xml);
use Encode;
use XML::LibXML;
use XML::LibXSLT;

## run parameter for debug
my $g_debug=0;

## the XML parser
my $parser = XML::LibXML->new();

## XSLT stylesheets used
my $xslts;
$xslts->{'aunex'}=&AuthorProfile::Common::load_xslt("$xslt_dir/aunex.xslt.xml");
$xslts->{'error'}=&AuthorProfile::Common::load_xslt("$xslt_dir/error.xslt.xml");
$xslts->{'multiple_results'}=&AuthorProfile::Common::load_xslt("$xslt_dir/multiple_results.xslt.xml");


my $cache;
my $cache_times;

## initialize auma
my $auma=&AuthorProfile::Common::json_retrieve($auma_file);    

## find full names from auma
my $full_names;
foreach my $key (keys %$auma) {
  if(defined($auma->{$key}->{'name'})) {
    $full_names->{$key}=$auma->{$key}->{'name'};
  }
}

## initialize navama
my $navama=&AuthorProfile::Common::json_retrieve($navama_file);

# 01/23/12 - James
# Deprecated in favor of MongoDB
## set up vema
#my $vema_db;
#eval { $vema_db = new BerkeleyDB::Hash
#         -Filename => $vema_db_file,
#         -Flags    => DB_RDONLY ;
#     };

#die $! if $@; 


## setup() can even be skipped for common cases. See CGI::Application doc
sub setup {
  my $self = shift;
  $self->start_mode('mode1');
  $self->run_modes(
                   'mode1' => 'show',
                  );
  #$self->param('cache' => $cache);
}

## shows result
## essentially splits the query between show_profile and do_search
sub show { 
  my $self = shift;  
  ## Get CGI query object
  my $q = $self->query();
  ## aunex is in parameter p
  my $aunex;
  $aunex = decode_utf8($q->param('p')) and return &show_profile($self,$aunex);
  ## to_find is in parameter q
  my $to_find;
  $to_find = decode_utf8($q->param('q')) and return &do_search($self,$to_find);
  return &fatal_error($self,"Neither parameter q nor p are set") ;
}

## search
sub do_search {
  my $self=shift;
  my $to_find=shift;
  ## allow to_find to contain _
  $to_find=~s|_+| |g;
  my $canonical_location="http://authorprofile.org/$to_find";
  my $name=normalize_name($to_find);
  ## fixme: normalize_name may not return a result
  if(not defined($name)) {
    $name=$to_find;
    #return &fatal_error($self,"Fixme: I can't handle the search '$to_find', it can't be normalized.") ;    
  }
  $self->header_add(-type => 'text/html',
                    -status => '201 Created',
                    -location => $canonical_location,
                    -charset => 'utf-8');
  ## do we have an author with a matching name variation?
  if(defined($name) and defined($navama->{$name})) {
    ## the simplest case, one name variation matches    
    if(scalar(@{$navama->{$name}})==1) {
      my $au_id=$navama->{$name}->[0];
      return &show_author_page($self,$au_id);
    }
    ## fixme: more than one author is implemented.
    my $profiles=join(', ',@{$navama->{$name}});
    chop $profiles;
    chop $profiles;
    return &fatal_error($self,"Fixme: I can't handle a common name variation '$name' shared by $profiles.") ;    
  }
  ## Look for an aunex, without error, because third parameter is set.
  ## The value of the third parameter avoids recalcultating a normalized value.
  ## FixMe: for debugging only done when there are several terms
  my $output;
  if(scalar(split(' +',$to_find)>1)) {
    $output=&show_profile($self,$to_find,$name);
    if($output) {
      return $output;
    }    
  }  
  ## perform a word navama search
  if($output=&navama_search($self,$name,'word')) {
    return $output;
  }
  ## perform a string navama serach
  if($output=&navama_search($self,$name,'string')) {
    return $output;
  }
  ## perform a string regex search
  if($output=&navama_search($self,$name,'regex')) {
    return $output;
  }
  return &fatal_error($self,"I did not find an aunex \"$to_find\" and no matching author name components.") ;
}

sub show_author_page {
  my $self=shift;
  my $au_id=shift;
  my $profile_html_file=$au_id;
  $profile_html_file=~s|^p([a-z])([a-z])([0-9]+)|/p/$1/$2/$3.html|;
  $profile_html_file="$html_dir/$profile_html_file";
  if(-R $profile_html_file) {
    return &read_file("$profile_html_file") ;
  }
  return &fatal_error($self,"I can't open the file '$profile_html_file'.") ;
}

## performs searches accounding to varios exactness degrees
sub navama_search {
  my $self=shift;
  my $to_find=shift;
  ## exact string
  my $exact=shift;
  my $regex;
  if($exact eq 'word') {
    $regex='\b'.quotemeta($to_find).'\b';
  }
  elsif($exact eq 'string') {
    $regex=quotemeta($to_find);
  }
  elsif($exact eq 'regex') {
    $regex="$to_find";
  }
  else {
    die "second parameter $exact is not supported by navama_search\n";
  }
  ## what has been found
  my $found;  
  ## find in the full_name
  foreach my $au_id (keys %$full_names) {
    while($found=&match_and_split($found,$full_names->{$au_id},$regex,$au_id)) {
      ## the above function call stores in _ the remainder of the match
      if(not defined($found->{'_'}->{$full_names->{$au_id}})) {
        last;
      }
      ## count the times we have found to enable a trivial relevance sorting
      ## count for both navas and au_ids
      my $full_name=$full_names->{$au_id};
      if(not defined($found->{'full_name'}->{$full_name})) {
        $found->{'full_name'}->{$full_name}=1;
      }
      else {
        $found->{'full_name'}->{$full_name}++;
      }
      if(not defined($found->{'count_full_name'}->{$full_name})) {
        $found->{'count_full_name'}->{$au_id}=1;
      }
      else {
        $found->{'count_full_name'}->{$au_id}++;
      }
      ## Increment nava count even though this not a nava.
      ## Tis makes it easier to find whether a unique 
      ## result has been found.
      $found=&make_found_count($found,$au_id,$full_name);      
    }
  }
  ## find in name variations 
  foreach my $nava (keys %$navama) {
    #print "finding '$regex' in '$nava'\n";
    while($found=&match_and_split($found,$nava,$regex)) {
      ## leave when there is no remainder define
      if(not defined($found->{'_'}->{$nava})) {
        last;
      }
      ## recall that the values in $navama->{$name} are arrays
      ## two authors may have the same name variation
      foreach my $au_id (@{$navama->{$nava}}) {
        ## count the times we have found to enable a trivial relevance sorting
        ## count for both navas and au_ids
        $found=&make_found_count($found,$au_id,$nava);
      }
    }
  }
  if(not defined($found->{'count_nava'})) {
    ## signal failure by empty return
    #print "found notihng\n";
    return;
  }
  ## if there is only one result return the result
  my @au_ids=keys %{$found->{'count_nava'}};
  if(scalar(keys %{$found->{'count_nava'}})==1) {
    ## show page of single found author
    return &show_author_page($self,$au_ids[0]);    
  }  
  ##return &fatal_error($self,"Case of several $exact-style matches not yet implemented.". Dumper $found) ;
  my $results_doc=&construct_results_xml($self,$found,$to_find);
  return $results_doc;
}


## matches and splits a string,
## records in $found
sub match_and_split {
  my $found=shift;
  my $string=shift;
  my $regex=shift;
  my $au_id=shift;
  ## where to match
  my $to_match;
  if(defined($found->{'_'}->{$string})) {
    $to_match=$found->{'_'}->{$string};
  }
  else {
    $to_match=$string;
  }
  #print "matcing '$to_match'\n";
  ## do the match
  if(not $to_match=~m|^(.*)($regex)(.*)$|i) {
    ## if there is a remainder from a previous call
    if(ref($found) and defined($found->{'_'}->{$string})) {
      push(@{$found->{'name'}->{$string}},$found->{'_'}->{$string});      
      delete $found->{'_'}->{$string};
    }
    ## the most likely case, no match at all
    return $found;
  }
  ## no 'else', as we must have returned from the previous case
  ## a match has taken place
  my $before=$1;
  my $middle=$2;
  my $after=$3;
  #print "before '$before', middle '$middle', after '$after'\n"; 
  ## build an array, with matching/non-matching points alternatning. 
  push(@{$found->{'name'}->{$string}},$before,$middle);
  ## record the remainder
  $found->{'_'}->{$string}=$after;
  ## more work to be done on the remaining part 
  return $found;
}


## counts results from nava, repeated for full
## names, therefore in a separater procedure
sub make_found_count {
  my $found=shift;
  my $au_id=shift;
  my $nava=shift;
  if(not defined($found->{'nava'}->{$nava})) {
    $found->{'nava'}->{$nava}=1;
  }
  else {
    $found->{'nava'}->{$nava}++;
  }
  ## count nava occurance
  if(not defined($found->{'count_nava'}->{$au_id})) {
    $found->{'count_nava'}->{$au_id}=1;
  }
  else {
    $found->{'count_nava'}->{$au_id}++;
  }
  ## add data about the minimum length of the name variation
  my $length=length($nava);
  if(not defined($found->{'min_length'}->{$au_id})) {
    $found->{'min_length'}->{$au_id}=$length;
  }
  elsif($found->{'min_length'}->{$au_id}>$length) {
    $found->{'min_length'}->{$au_id}=$length;
  }       
  ## add data about the maximum length of the name variation
  if(not defined($found->{'max_length'}->{$au_id})) {
    $found->{'max_length'}->{$au_id}=$length;
  }
  elsif($found->{'max_length'}->{$au_id}<$length) {
    $found->{'max_length'}->{$au_id}=$length;
  }       
  return $found;
}


## builds XML from $found
sub construct_results_xml {
  my $self=shift;
  my $found=shift;
  my $to_find=shift;
  my $doc=$parser->createDocument('1.0','utf-8');
  my $results_element=$doc->createElement('results');
  $results_element->setAttribute('to_find',$to_find);
  ## construct results doc from the results
  my $sort_results = sub {
    ## au_id with the most matches in full name
    my $first_diff=(($found->{'count_full_name'}->{$b} // 0 ) <=> ($found->{'count_full_name'}->{$a} // 0));
    if($first_diff) {
      return $first_diff;
    }
    ## au_id with the most matches in name variation
    my $second_diff=($found->{'count_nava'}->{$b} <=> $found->{'count_nava'}->{$a});
    if($second_diff) {
      return $second_diff;
    }
    ## au_id with smallest minimal name variation
    my $third_diff=($found->{'min_length'}->{$a} <=> $found->{'min_length'}->{$b});
    if($third_diff) {
      return $third_diff;
    }
    ## au_id with smallest maximal name variation
    my $fourth_diff=($found->{'max_length'}->{$a} <=> $found->{'max_length'}->{$b});
    return $fourth_diff;
  };  
  my @au_ids=keys %{$found->{'count_nava'}};
  my @results=sort $sort_results @au_ids;  
  my $found_authors=0;
  foreach my $au_id (@results) {    
    if(not defined($found->{'count_full_name'}->{$au_id})) {
      $found->{'count_full_name'}->{$au_id}=0;
    }
    my $author_element=$doc->createElement('author');    
    $author_element->setAttribute('au_id',$au_id);
    $author_element->setAttribute('found_in_full_name_count',$found->{'count_full_name'}->{$au_id});
    $author_element->setAttribute('found_in_nava_count',$found->{'count_nava'}->{$au_id});
    $author_element->setAttribute('min_nava_length',$found->{'min_length'}->{$au_id});
    $author_element->setAttribute('max_nava_length',$found->{'max_length'}->{$au_id});    
    my $name_element=$doc->createElement('name');
    #$name_element->appendText($auma->{$au_id}->{'name'});
    ## agrage
    ## add full name
    my $full_name=$auma->{$au_id}->{'name'};
    my $count_parts=0;
    foreach my $part (@{$found->{'name'}->{$full_name}}) {
      my $string=$found->{'name'}->{$full_name}->[$count_parts];
      if($count_parts % 2) {
        $name_element->appendTextChild('high',$string);
      }
      else {
        $name_element->appendTextChild('normal',$string);
      }
      $count_parts++
    }
    ## if there have been any parts
    if($count_parts) {
      $author_element->appendChild($name_element);
    }
    else {
      $author_element->appendTextChild('name',$auma->{$au_id}->{'name'});
    }
    ## add name variations
    foreach my $nava (@{$auma->{$au_id}->{'nava'}}) {
      my $nava_element=$doc->createElement('name_variation');
      $count_parts=0;
      foreach my $part (@{$found->{'name'}->{$nava}}) {
        my $string=$found->{'name'}->{$nava}->[$count_parts];
        if($count_parts % 2) {
          $nava_element->appendTextChild('high',$string);
        }
        else {
          $nava_element->appendTextChild('normal',$string);
        }
        $count_parts++
      }
      ## if there have been any parts 
      if($count_parts) {
        $author_element->appendChild($nava_element);
      }
    }
    $found_authors++;
    $results_element->appendChild($author_element);
  }
  #$results_element->appendText(Dumper $found); 
  ## add English for results count
  ##if($found_authors < 13) {
  ##  $results_element->setAttribute('count')=num2en($found_authors);
  ##}
  $doc->setDocumentElement($results_element);
  my $results = eval { 
    $xslts->{'multiple_results'}->transform($doc);
  };
  ## bytes, not utf-8 string, cgi::fast wants it this way
  my $output=$xslts->{'multiple_results'}->output_as_bytes($results);
  ##$doc->toFile("/tmp/results.xml",1);
  ##my $out=$doc->toString(2);
  ##return &fatal_error($self,"I found several authors\n\n" . $out. "\nFurther steps are not yet implemented.\n") ;
  return $output;
}


sub show_profile {
  my $self=shift;
  my $aunex=shift;
  ## show no error? To be set to true if we are 
  ## calling from the search
  my $show_errors=shift // 0;
  my $canonical_location="http://authorprofile.org/=$aunex";
  my $output = '';
  ## if not called by the search
  my $normal_name;
  if(not $show_errors) {
    $normal_name = &normalize_name($aunex);
  }
  else {
    ## the search has already normalized the name, and 
    ## supplied it as the third parameter
    $normal_name=$show_errors;
  }
  if(not $normal_name) {
    return &fatal_error($self,"aunex \"$aunex\" could not be normalized") ;
  }
  ## method from cgi::application to create or change headers
  $self->header_add(-type => 'text/html',
                    -status => '201 Created',
                    -location => $canonical_location,
                    -charset => 'utf-8');
  if(defined($cache->{$normal_name}) and 
     $cache_times->{$normal_name} > time-86400) {
    return $cache->{$normal_name}."\n<!-- served from cache -->\n";
  }
  my $file_name .= &authorname_to_filename($normal_name,'silent');
  ## the auvert_dir is set in AuthorProfile::Conf
  my $amf_file = "$auvert_dir/$file_name";
  if(not -f $amf_file) {
    return &fatal_error($self,"no such file: '$amf_file' for aunex \"$aunex\" normalized as \"$normal_name\"") ;
  }
  my $dom = eval { $parser->parse_file($amf_file);};
  if($@) {
    if($show_errors) {
      return &fatal_error($self,$@);
    }
    ## return without error
    return 0;
  }
  ## changes $dom to add leavout attribute
  ## for the author, thus avoiding linking the
  ## page to itself  
  my $document_element=$dom->documentElement;
  $document_element=&AuthorProfile::Common::add_status($document_element,$auma,$aunex);
  my $errors;
  $document_element=&insert_vert_data_xml($dom,$normal_name,\$errors,$g_debug);
  #return $document_element->toString();
  # 01/23/12 - James
  # This must have the original aunex passed.  Please see Network.pm.
  $document_element=&insert_horizontal_xml($dom,$aunex,\$errors);  

  my $results = eval { 
    $xslts->{'aunex'}->transform($dom, 'aunex' => "'$aunex'") ;
  };
  if($@) {
    if($show_errors) {
      return &fatal_error($self,"XSLT transformation error: $@");
    }
    ## return without error
    return 0;
  }
  ## bytes, not utf-8 string, cgi::fast wants it this way
  $output=$xslts->{'aunex'}->output_as_bytes($results);
  ## if there is the ap:vertical element, fill cache
  if($document_element->getElementsByTagNameNS($ap_ns, 'vertical')) {
    $cache->{$normal_name}=$output;
    $cache_times->{$normal_name}=time;
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

## fatal_error
sub fatal_error {
  my $self = shift;  
  my $error =shift;
  my $dom = XML::LibXML::Document->new('1.0','utf-8');
  my $error_element=$dom->createElement('error');
  $error_element->appendTextChild('message',$error);
  $error_element->appendTextChild('query_object',Dumper($self));
  $dom->setDocumentElement($error_element);
  $self->header_add(-type => 'text/html',
                    -charset => 'utf-8');
  my $results = eval { 
    $xslts->{'error'}->transform($dom); 
  };
  if($@) {
    ## even more fatal, we can't even show a fatal error!
    return; 
    #return &fatal_error($self,$@);
  }
  ## bytes, not utf-8 string, cgi::fast wants it this way
  #print $@;
  my $output=$xslts->{'error'}->output_as_bytes($results);
  return $output;
}

#sub log_me {
#  my $in=shift;
#  my $date=`date -I`;
#  chomp $date;
#  my $log_file="$log_dir/author_profile_$date.log";
#  open(L, ">>:encoding(UTF-8)", "$log_file");
#  $|=1;
#  print L $in, "\n";
#  close L;
#}



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
