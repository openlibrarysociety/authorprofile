#!/usr/bin/perl

use strict;
use warnings;

use lib qw( /home/aupro/ap/perl/lib /home/aupro/usr/lib/perl );

use Data::Dumper;
use XML::LibXML;
use Date::Format;
use AuthorProfile::Common qw(
                              open_db 
                              close_db
                              get_from_db_json
                              put_in_db_json
                              get_mongodb_collection
                              put_in_mongodb
                              get_from_mongodb
                              json_retrieve
                           );
use AuthorProfile::Conf;
use Encode;
use utf8;

binmode(STDOUT,"utf8");

use Sys::RunAlone;
use Proc::ProcessTable;

# Global Constants

my $DEBUG=0;
my $VERT_LOG_PATH="$home_dir/ap/var/log/vertical";

if(not -d $VERT_LOG_PATH) {
  `mkdir $VERT_LOG_PATH` or die "Fatal error: Could not create directory $VERT_LOG_PATH.\n";
}

my $VERT_BIN_PATH="$home_dir/ap/perl/bin/generate_vid.pl";
my $g_delay=300;
my $g_maxd=5;
my $g_verbose=1;
my $g_child_procs=undef;

# The number of instances of the vertical integration data calculation scripts running on the server.
my $g_vert_procs_running=0;
# The maximal amount of instances that the vertical integration data calculation script is permitted to run (given the resources of the server).
my $g_max_running_vert_procs=1;

my $g_vema_db_file;
my $g_max_nodes;
my $g_time_limit;
my $g_b_priority;
my $g_authorlist_script="$home_dir/ap/perl/bin/list_authors";

#### Informal Documentation ####

# The noma ("node master")
# Note: This is of no immediate concern to the calculation of the vertical integration data.
# $noma->{[SID]}->{'last_change_date'}
# $noma->{[SID]}->{'began_calculation'}
# $noma->{[SID]}->{'ended_calculation'}
# $noma->{[SID]}->{'furthest_depth'}

# PRIORITY FOR NOMA
# 1) new authors are calculated first
# 2) authors for which there are no ended_calculations values are calculated next
# 3) authors for which the furthest_depth does not match the maxd

# So, for sorting
# new authors are first pushed to the array
# then, authors for which there are no ended calculations are sorted
# THIS INCLUDES ENDED CALCULATIONS THAT ARE OLDER THAN began_calculations
# higher priority is given to those for which the begin time is older
# as these authors are sorted, they must be popped from an array of some sort
# those authors for which there were ended calculations are then further sorted
# higher priority is given to those for whom the ended_calculations values are older
# highest priority is given to those authors for whom the furthest depth is the lowest
# these must be popped as well
# finally, those remaining authors sorted by ended_calculations values are calculated for 

my @g_authors;

### MongoDB Globals
my $g_collec;

eval { $g_collec=AuthorProfile::Common::get_mongodb_collection('noma'); };
if($@) {
  die "Fatal Error: Could not connect to authorprofile.noma: $!";
}
###


sub refresh_vert_procs_running {

  my $t = new Proc::ProcessTable;
  my @vert_pids;
  
  # First obtain the pid's of all running instances of the vertical script...
  foreach my $p (@{$t->table}) {
    if(($p->{'fname'} eq 'generate_vid.pl')) {
      print "Found an instance of the vertical script with a process ID of ", $p->{'pid'}, " running.\n";
      push(@vert_pids, $p->{'pid'});
    }
  }
  
  # ...and then obtain the authors for which the vertical integration data is currently being calculated.
  my $running_authors;
  
  foreach my $vert_pid (@vert_pids) {
    foreach my $p (@{$t->table}) {
      if($p->{'pid'} eq $vert_pid) {
        # This is tedious simply due to the impossibility of clearly distinguishing flags and options from filenames on the command line invocation of the vertical script.
        my $vert_options=$p->{'cmndline'};
        $vert_options=~s|/usr/bin/perl||;
        $vert_options=~s|/home/mamf/perl/vertical||;
        my $running_author=$vert_options;
        $vert_options=~s|/home/mamf/opt/amf/3lib/am/.*$||;
        $vert_options=~s|^\s*||;
        $vert_options=~s|\s*$||;
        
        $running_author=~s|/home/mamf/opt/amf/3lib/am/||;
        $running_author=~s|.amf.xml||;
        $running_author=~s|././||;
        $running_author=~s|\Q$vert_options\E||;
        $running_author=~s|^\s*||;
        
        # If there are already instances of the vertical script running for this author $running_author, issue a warning to STDERR.
        if(exists($running_authors->{$running_author})) {
          warn("Warning: More than one instance of the vertical script found to be running for $running_author!\n");
          next;
        }
        $running_authors->{$running_author}=1;
      }
    }
  }
  return $running_authors;
}

# REF HASH sub sort_authors (REF LIST, )
sub sort_authors {

  my $in_authors=shift;
  my $field=shift;
  my $sort_order=shift;

  my $condition=shift;
  my $cond1=shift;
  my $cond2=shift;

  my @records;

  if(not scalar @{$in_authors}) {
    warn "Empty \$in_authors in sort_authors";
    return $in_authors;
  }

  my @results;
  foreach my $author (@{$in_authors}) {
    print "Looking for $author in authorprofile.noma...\n";
    @results=AuthorProfile::Common::get_from_mongodb($g_collec,{'author' => $author});

    my $record=pop @results;
    
    if(not $record) {
      die "Fatal Error: Could not retrieve record for $author in sort_authors";
    }
    push @records,$record;
  }

  my @sorted_records;

  if($condition) {
    foreach my $author_record (@records) {
      if(not ($author_record->{$cond1} or $author_record->{$cond2})) {
        die 'Records not purged properly';
      }
      # 'GT' flag
      if($condition eq 'GT') {
        if($author_record->{$cond1} > $author_record->{$cond2}) {
          push @sorted_records,$author_record->{'author'};
        }
      }
      else {
        die "Fatal Error: Bad \$condition value passed";
      }
    }
  }

  if($sort_order) {
    # Ascending (alternative sorting scheme)
    @sorted_records=(sort {$a->{$field} <=> $b->{$field}} @records);
  }
  else {
    # Descending (default sorting scheme)
    @sorted_records=(sort {$b->{$field} <=> $a->{$field}} @records);
  }
  if(not @sorted_records) {
    die "Fatal Error: Failed to sort records";
  }

  my @sorted_authors;
  foreach my $sorted_record (@sorted_records) {
    push @sorted_authors,$sorted_record->{'author'};
  }

  return \@sorted_authors;
}

sub get_authors_sorted_by_field {

  # The source list of authors
  my $in_authors=shift;

  if(not scalar $in_authors) {
    warn 'Warning: Empty $in_authors passed to get_authors_sorted_by_field';
    return $in_authors;
  }

  my $field=shift;
  my $id_field=shift;

  my $condition=shift;
  my $cond1=shift;
  my $cond2=shift;

  my $sort_order=shift;

  my $sorted_authors=sort_authors(\@{$in_authors},$field,$sort_order,$condition,$cond1,$cond2);

  my $counter=0;
  foreach my $sorted_author (@{$sorted_authors}) {
    push @g_authors,$sorted_author;
    splice @{$sorted_authors},$counter,1;
    $counter++;
  }

  return $in_authors;
}

sub get_authors_missing_field {

  my $author_sids=shift;

  if(not scalar $author_sids) {
    return $author_sids;
  }

  my $field=shift;
  my $id_field=shift;
  my $sort=shift;
  my $sort_field=shift;
  my $sort_order=shift;

  my $counter=0;
  my @filtered_authors;
  foreach my $author (@{$author_sids}) {

    my @results=AuthorProfile::Common::get_from_mongodb($g_collec,{'author' => $author});
    my $record=pop @results;

    if(not $record) {
      warn "Warning: Could not retrieve the record for $author";
      next;
    }

    if(not $record->{$field}) {
      push @filtered_authors,$author;
      splice @{$author_sids},$counter,1;
      print "$author missing field $field\n" if $g_verbose > 0;
    }
    $counter++;
  }

  if($sort) {
    if(not @filtered_authors) {
      warn "Could find no authors missing a value for $field";
      return $author_sids;
    }

    my $sorted_filtered_authors=sort_authors(\@filtered_authors,$sort_field,$sort_order);

    if(not scalar @{$sorted_filtered_authors}) {
      return $author_sids;
    }
    else {
      foreach my $sorted_filtered_author (@{$sorted_filtered_authors}) {
        push @g_authors,$sorted_filtered_author;
      }
      return $author_sids;
    }
  }
  else {
    foreach my $author (@filtered_authors) {
      push @g_authors,$author;
    }
  }


#  print 'missing debug: ',@g_authors;
  return $author_sids;
}




sub main {

  # Set the 
  &proc_input;

  # Loop infinitely for the wrapper
  while(1) {
    # Obtain the SID's of all registered authors:
    my @author_sids=gather_authors_from_profile_dir($ap_dir);
    
    if(not @author_sids) {
      die("ERROR: Could not find authors!\n");
    }

    my $h_author_sids;
    
    # Why is this a hash? Perhaps I've made a mistake...
    # Loop through the SID of each registered author
    foreach my $author_sid (@author_sids) {
      $h_author_sids->{$author_sid}=1;
    }
    
    # Obtain the authors for which the vertical integration calculations haven't been performed.
    my @new_authors;
    
    #    my $author_sid=undef;
    
    my $author_record;
    
    #  $author_record=&AuthorProfile::Common::get_from_db_json($noma_db, $author_sid);
    
    my $authors_h;
    
    my @authors=[];
    
    my $h_new_authors;
    #    foreach my $author_sid (@author_sids) {
#    foreach my $author_sid (keys %{$h_author_sids}) {
    foreach my $author_sid (@author_sids) {

      my @results;
      eval { @results=AuthorProfile::Common::get_from_mongodb($g_collec,{'author' => $author_sid}); };
      if($@) {
        die "Fatal Error: Could not retrieve the record for $author_sid in authorprofile.noma.";
      }
      $author_record=pop @results;
      if(not $author_record) {
#        print "Generating the last_change_date for the new author $author_sid...\n" if $g_verbose > 0;
        print "No record in authorprofile.noma for $author_sid\nPopulating the authorprofile.noma collection with authors...\n" if $g_verbose > 0;
        # To be implemented:
        # Enter a record for this author with a value for last_change_date
        if(&populate_noma_mongodb) {
          die 'Fatal Error: Could not populate the authorprofile.noma database';
        }
        die "need to populate db for $author_sid";
        delete($h_author_sids->{$author_sid});
        next;
      }
    }

    # Should be raising exceptions...
    get_authors_missing_field(\@author_sids,'began_calculation','author',1,'last_change_date');

    get_authors_missing_field(\@author_sids,'ended_calculation','author',1,'began_calculation');

    get_authors_sorted_by_field(\@author_sids,'ended_calculation','author','GT','began_calculation','ended_calculation');

#    die 'debug main',Dumper @g_authors;    

    get_authors_sorted_by_field(\@author_sids,'furthest_depth');

    if(scalar @g_authors > 0) {
      print 'A total of ',scalar @g_authors," authors prioritized for vertical integration calculations.\n" if($g_verbose > 0);
    }
    else {
      #if($g_verbose > 0) { print("No noma entries with a value for 'last_change_date found; Running ap_authorlist...\n"); 
      #print "No noma entries with a value for 'last_change_date found; Running ap_authorlist...\n" if($g_verbose > 0);
      die "No entries in authorprofile.noma with a value for 'last_change_date' found - populate the collection\n" if($g_verbose > 0);
    }

#    die 'splicing might be a problem';
#    die Dumper @g_authors;
    
    # Sort by times stored for the last ended calculation.
    
    my $max_value=undef;
    my $recent_author=undef;
    
    #    my $total_authors = scalar(keys %{$authors});
    my $total_authors=$#g_authors;
    my $author_counter = 0;
    
    # So, for sorting
    # new authors are first pushed to the array
    # then, authors for which there are no ended calculations are sorted
    # THIS INCLUDES ENDED CALCULATIONS THAT ARE OLDER THAN began_calculations
    # higher priority is given to those for which the begin time is older
    # as these authors are sorted, they must be popped from an array of some sort
    # those authors for which there were ended calculations are then further sorted
    # higher priority is given to those for whom the ended_calculations values are older
    # highest priority is given to those authors for whom the furthest depth is the lowest
    # these must be popped as well
    # finally, those remaining authors sorted by ended_calculations values are calculated for 
    
    my $current_author;
    
    my $t = new Proc::ProcessTable;
    my @vert_pids;
    
    # First obtain the pid's of all running instances of the vertical script...
    foreach my $p (@{$t->table}) {
      if($p->{'fname'} eq 'generate_vid.pl') {
        push(@vert_pids, $p->{'pid'});
      }
    }
    
    # ...and then obtain the authors for which the vertical integration data is currently being calculated.
    
    #my @running_authors;
    my $running_authors;


    
    foreach my $vert_pid (@vert_pids) {
      foreach my $p (@{$t->table}) {
        if($p->{'pid'} eq $vert_pid) {
          # This is tedious simply due to the impossibility of clearly distinguishing flags and options from filenames on the command line invocation of the vertical script.
          my $vert_options=$p->{'cmndline'};
          $vert_options=~s|/usr/bin/perl||;
          $vert_options=~s|\Q/home/aupro/ap/perl/bin/generate_vid\.pl\E||;
          my $running_author=$vert_options;
          $vert_options=~s|\Q/home/aupro/ap/amf/3lib/am/\E.*$||;
          $vert_options=~s|^\s*||;
          $vert_options=~s|\s*$||;
          
          $running_author=~s|\Q/home/aupro/ap/amf/3lib/am/\E||;
          $running_author=~s|\Q.amf.xml\E||;
          $running_author=~s|././||;
          $running_author=~s|\Q$vert_options\E||;
          $running_author=~s|^\s*||;
          
          # If there are already instances of the vertical script running for this author $running_author, issue a warning to STDERR.
          if(exists($running_authors->{$running_author})) {
            warn("Warning: More than one instance of the vertical script found to be running for $running_author!\n");
            next;
          }
          $running_authors->{$running_author}=1;
        }
      }
    }
    
    # Set the index for running instances of the vertical script to the number of running authors.
    $g_vert_procs_running=keys(%{$running_authors});
    
    my $vert_output;

    foreach my $author (@g_authors) {

      # If this author doesn't currently have an instance of the vertical script running...
      if(not exists($running_authors->{$author})) {
        # ...and if the maximal instances of the vertical script hasn't been reached yet...
#        print "The vertical calculations are not currently being performed for $author.\n";
        while($g_vert_procs_running >= $g_max_running_vert_procs) {
          print("The maximum instances of the vertical integration calculation script are now running.\n");
          print "Scripts are running for the following authors:\n";
          foreach my $running_author (keys %{$running_authors}) { print "$running_author\n"; }

          print("Next author to be calculated when a script instances finishes: $author\n");
          print("Waiting for an instance of the vertical integration calculation script to finish...\n");
          sleep($g_delay);
          $running_authors=&refresh_vert_procs_running;
          $g_vert_procs_running=scalar keys(%{$running_authors});
        }

        my $noma_db=AuthorProfile::Common::get_from_mongodb($g_collec,{'author' => $author});
        my $depth=2;

        if($author_record->{'furthest_depth'}) {
          if($author_record->{'furthest_depth'} >= 2 and ($author_record->{'furthest_depth'} + 1 <= $g_maxd)) {
            $depth=$author_record->{'furthest_depth'} + 1;
          }
          elsif($author_record->{'furthest_depth'} <= 0) {
            warn "Warning: furthest_depth value corrupt for $author!\n";
            next;
          }
        }
        elsif(not $author_record) {
          die "Fatal Error: Could not obtain noma record for $author.\n";
        }

        my $vert_output_file=$VERT_LOG_PATH . '/vertical_' . $author . "_depth_$depth" . '_time_' . time() . '.log';
        my $acis_profile=$author;
        $acis_profile=~s|^p||;
        $acis_profile=~s|\d$||;
        $acis_profile=~s|\B|/|g;
        
        $acis_profile = $ap_dir . '/' . $acis_profile . '/' . $author . '.amf.xml';

        if(not -f $acis_profile) {
          #warn("Error: Could not find file $acis_profile - skipping $author...\n");
          die "Fatal Error: Could not find file $acis_profile for \$acis_profile\n";
          next;
        }
        
        if(not -f $VERT_BIN_PATH) {
          die("Fatal Error: $VERT_BIN_PATH could not be found\n");
        }
        
        my $vert_script_invoc=$VERT_BIN_PATH . ' --maxd=' . $depth . ' ' . $acis_profile . ' > ' . $vert_output_file . ' 2>&1 &';
        
        # ...then launch another instance of the vertical script...
        print "Performing vertical integration calculations for $author...\n";

        eval {
          $vert_output=`$vert_script_invoc`;
        };
        if($@) {
          warn("Error: vertical integration calculation script invocation returned the following error\(s\): $! !\n");
          next;
        }
        # ...and, if the script is running properly, increment the number of vertical instances running.
        
        # The value of $vert_output does NOT necessarily indicate that the script has been launched successfully!
        
        $running_authors=&refresh_vert_procs_running;
        $g_vert_procs_running=scalar keys(%{$running_authors});
        
        print("Currently running $g_vert_procs_running instances of the vertical integration calculation script....\n");
      } # end of conditional that checks to see if SID from master SID array @authors has any VIC scripts currently running
    } # end of $running_authors->{$sorted_author} foreach loop
  } # end of $sorted_authors->{'authors'} foreach loop
} # At this point, every single author prioritized has been cycled through
 # end of defined(@author_sids) while loop
  # Once this loop has been run through, the author prioritization process begins anew...

&main();

sub populate_noma_mongodb {

  my $acis_values;
  $acis_values=AuthorProfile::Common::json_retrieve($acis_file);
  my $results;

  for my $acis_author (keys %{$acis_values}) {
    $results=AuthorProfile::Common::put_in_mongodb($g_collec,{'last_change_date' => $acis_values->{$acis_author}},'author',$acis_author);
  }

  print 'authorprofile.noma successfully populated with authors from the ACIS system' if $g_verbose > 0;
  return 0;
}

#IMPORTED FROM OTHER SCRIPTS

## gather author information
sub gather_authors_from_profile_dir {
  my $profile_dir=shift;
  my @author_sids;
  foreach my $file (`find $profile_dir -type f -name '*.xml'`) {
    chomp $file;
    open my $fh, "$file";
    binmode $fh; # drop all PerlIO layers possibly created by a use open pragma
    my $doc = eval {XML::LibXML->load_xml(IO => $fh);};
    if(not $doc) {
      warn "could not parse $file";
      next;
    }
    &work_with_doc($doc,\@author_sids);
  }
  return @author_sids; 
}

## write XML document
sub work_with_doc {
  my $doc=shift;
  my $author_sids=shift;
#  print(Dumper @$author_sids);
#  exit;
  my $data_element=$doc->documentElement;
  ## the sid of the author is always last
  my $sid_element= pop @{$data_element->getElementsByTagNameNS($acis_ns, 'shortid')};
  my $sid=$sid_element->textContent;
  ## is this an author?
  my $accepted_element = pop @{$data_element->getElementsByTagName('isauthorof')};
  # This checks to ensure that no one author with no claimed documents has their SID passed to the $author_sids structure.
  # Unless I am mistaken, this is what function the $empty_array statements serve.
  if(not $accepted_element) {
    return undef;
  }
  # ???
  # There are AMF elements with the tag name 'empty-array'?
  my $emptyarray_element = pop @{$accepted_element->getElementsByTagName('empty-array')};
  if($emptyarray_element) {
    ## this is not an author
    #print "$name is not an author\n";
    return undef;
  }
  push(@$author_sids, $sid);
  return 1;
}

# This needs to be placed into AuthorProfile::Common

sub proc_args {

  my $input_var=shift;



##################################
# Exact string comparisons
##################################

  if($input_var eq '-q' or $input_var eq '--quiet') {
    $g_verbose=0;
    return;
  }

  if($input_var eq '-D' or $input_var eq '--debug') {
    $DEBUG=1;
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
    $g_vema_db_file=$vema_db_file;
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
    &proc_args($input_var);
  }
}

# For Sys:Runalone
__END__
