#!/usr/bin/perl

use strict;
use warnings;

use lib qw( /home/aupro/ap/perl/lib /home/aupro/usr/lib/perl );

use AuthorProfile::Conf;
use AuthorProfile::Vertical;
use AuthorProfile::Common qw(get_from_mongodb);

use Data::Dumper;

# This is deprecated
#require 'header.pl';
my $VERTICALD_PATH="$ENV{'HOME'}/ap/perl/bin/vertical/verticald";
require "$VERTICALD_PATH/proc_input.pl";
require "$VERTICALD_PATH/gather_authors_from_profile_dir.pl";
# This is deprecated
# require "populate_noma_mongodb.pl";
require "$VERTICALD_PATH/get_authors_missing_field.pl";
require "$VERTICALD_PATH/get_authors_sorted_by_field.pl";
require "$VERTICALD_PATH/refresh_vert_procs_running.pl";
require "$VERTICALD_PATH/sort_authors.pl";
require "$VERTICALD_PATH/refreshMongoDBConn.pl";

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
    my $author_record;
    my $authors_h;
    my @authors=[];
    my $h_new_authors;

    foreach my $author_sid (@author_sids) {

      # Ensure that the connection does not die.
      $COLL=MongoDB::Connection->new->get_database('authorprofile')->get_collection('noma') or die "Fatal Error: Could not retrieve a new connection to the MongoDB collection authorprofile.noma: $!";
      
      my @results;
      eval { @results=AuthorProfile::Common::get_from_mongodb($COLL,{'author' => $author_sid}); };
      if($@) {
        die "Fatal Error: Could not retrieve the record for $author_sid in authorprofile.noma.";
      }
      $author_record=pop @results;

      if(not $author_record) {
        warn "Warning: No value for last_change stored for author $author_sid.";
        @author_sids=grep(!/$author_sid/,@author_sids);
        next;
        # die "No record in authorprofile.noma for $author_sid\nPopulating the authorprofile.noma collection with authors...\n" if $VERBOSE > 0;
      }
    }

    # Should be raising exceptions if these fail...
    @AUTHORS=get_authors_missing_field(\@author_sids,'began_calculation','author',1,'last_change_date');
    @AUTHORS=get_authors_missing_field(\@author_sids,'ended_calculation','author',1,'began_calculation');
    die Dumper @AUTHORS;
    get_authors_sorted_by_field(\@author_sids,'ended_calculation','author','GT','began_calculation','ended_calculation');
    get_authors_sorted_by_field(\@author_sids,'furthest_depth');

    if(scalar @AUTHORS > 0) {
      print 'A total of ',scalar @AUTHORS," authors prioritized for vertical integration calculations.\n" if($VERBOSE > 0);
    }
    else {
      #if($VERBOSE > 0) { print("No noma entries with a value for 'last_change_date found; Running ap_authorlist...\n"); 
      #print "No noma entries with a value for 'last_change_date found; Running ap_authorlist...\n" if($VERBOSE > 0);
      die "No entries in authorprofile.noma with a value for 'last_change_date' found - populate the collection\n" if($VERBOSE > 0);
    }

#    die 'splicing might be a problem';
#    die Dumper @AUTHORS;
    
    # Sort by times stored for the last ended calculation.
    
    my $max_value=undef;
    my $recent_author=undef;
    
    #    my $total_authors = scalar(keys %{$authors});
    my $total_authors=$#AUTHORS;
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
      if($p->{'fname'} eq 'vertical.pl') {
        push(@vert_pids, $p->{'pid'});
      }
    }
    
    # ...and then obtain the authors for which the vertical integration data is currently being calculated.
    
    #my @running_authors;
    my $running_authors;
    my @runningAuthors=getRunningVerticalInstances;

    
    
#    foreach my $vert_pid (@vert_pids) {
#      foreach my $p (@{$t->table}) {
#        if($p->{'pid'} eq $vert_pid) {

          # To do: Restructure with awk
#          my $vert_options=$p->{'cmndline'};
#          $vert_options=~s|/usr/bin/perl||;
#          $vert_options=~s|\Q/home/aupro/ap/perl/bin/vertical\.pl\E||;
#          my $running_author=$vert_options;
#          $vert_options=~s|\Q/home/aupro/ap/amf/3lib/am/\E.*$||;
#          $vert_options=~s|^\s*||;
#          $vert_options=~s|\s*$||;
          
#          $running_author=~s|\Q/home/aupro/ap/amf/3lib/am/\E||;
#          $running_author=~s|\Q.amf.xml\E||;
#          $running_author=~s|././||;
#          $running_author=~s|\Q$vert_options\E||;
#          $running_author=~s|^\s*||;
          
          # If there are already instances of the vertical script running for this author $running_author, issue a warning to STDERR.

#          if(grep { $_ eq $running_author } @runningAuthors) {
#            warn "Warning: More than one instance of the vertical script found to be running for $running_author!\n" if $VERBOSE;
#            next;
#          }

          #if(exists($running_authors->{$running_author})) {
           # warn("Warning: More than one instance of the vertical script found to be running for $running_author!\n");
           # next;
          #}
#          push @runningAuthors,$running_author;
          # $running_authors->{$running_author}=1;
#        }
#      }
#    }
    
    # Set the index for running instances of the vertical script to the number of running authors.
    $VERT_PROCS=scalar @runningAuthors;
    #$VERT_PROCS=keys(%{$running_authors});
    
    my $vert_output;

    foreach my $author (@AUTHORS) {

      # If this author doesn't currently have an instance of the vertical script running...
      if(not grep {$_ eq $author} @runningAuthors) {
      # if(not exists($running_authors->{$author})) {
        # ...and if the maximal instances of the vertical script hasn't been reached yet...
#        print "The vertical calculations are not currently being performed for $author.\n";
        while($VERT_PROCS >= $MAX_VERT_PROCS) {

          if($VERBOSE) {
            print "The maximum instances of the vertical integration calculation script are now running.\nScripts are running for the following authors:\n";
            foreach (@runningAuthors) {print "$_\n"}
            # foreach my $running_author (keys %{$running_authors}) { print "$running_author\n"; }
            print "Next author to be calculated when a script instances finishes: $author\nWaiting for an instance of the vertical integration calculation script to finish...\n"
          };

          sleep($DELAY);

          $running_authors=&refresh_vert_procs_running;
          $VERT_PROCS=scalar @runningAuthors;
          # $VERT_PROCS=scalar keys(%{$running_authors});
        }

        my $noma_db=AuthorProfile::Common::get_from_mongodb($COLL,{'author' => $author});
        my $depth=2;

        if($author_record->{'furthest_depth'}) {
          if($author_record->{'furthest_depth'} >= 2 and ($author_record->{'furthest_depth'} + 1 <= $MAX_DIST)) {
            $depth=$author_record->{'furthest_depth'} + 1;
          }
          elsif($author_record->{'furthest_depth'} <= 0) {
            warn "Warning: furthest_depth value corrupt for $author!\n" if $VERBOSE;
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
          die "Fatal Error: $VERT_BIN_PATH could not be found\n";
        }
        
        my $vert_script_invoc='nice -n15 ' . $VERT_BIN_PATH . ' --maxd=' . $depth . ' ' . $acis_profile . ' > ' . $vert_output_file . ' 2>&1 &';

        # ...then launch another instance of the vertical script...
        print "Performing vertical integration calculations for $author...\n" if $VERBOSE;

        if(not $DEBUG) {
          eval {
            die 'DEBUG';
            $vert_output=`$vert_script_invoc`;
          };
          if($@) {
            warn "Error: vertical integration calculation script invocation returned the following error\(s\): $!\n" if $VERBOSE;
            next;
          }
        }


        # ...and, if the script is running properly, increment the number of vertical instances running.
        
        # The value of $vert_output does NOT necessarily indicate that the script has been launched successfully!
        
        $running_authors=&refresh_vert_procs_running;
        $VERT_PROCS=scalar @runningAuthors;
        # $VERT_PROCS=scalar keys(%{$running_authors});
        
        print "Currently running $VERT_PROCS instances of the vertical integration calculation script....\n" if $VERBOSE;
      } # end of conditional that checks to see if SID from master SID array @authors has any VIC scripts currently running
    } # end of $running_authors->{$sorted_author} foreach loop
  } # end of $sorted_authors->{'authors'} foreach loop
} # At this point, every single author prioritized has been cycled through
 # end of defined(@author_sids) while loop
  # Once this loop has been run through, the author prioritization process begins anew...

&main();

# For Sys:RunAlone
__END__
