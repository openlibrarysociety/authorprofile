#!/usr/bin/perl

use strict;
use warnings;

sub generate_vema {

  my $authors=shift;

  # Informal Documentation
  # $authors->{'w'}->$[AUTHOR]=

  my $poma=shift;
  my $dist;
  my $r;

  # Informal; Documentation
  # $r->{'p'}->{$[DISTANCE]}->{$[NODE]}=$[SIBLING NODE];
  # n1 - n2
  #    \
  #      n3
  # For both n2 and n3, n1 is the {'p'} value at a distance of i
  # $r->{'w'}->{$[NODE]}->{$[NODE]}=$[WEIGHT]
  # The weight of a given edge can only be calculated so long as the total number of works upon which two authors is cached within a data structure

  # To give a visualization of the completion of vema exploration.
  my $author_counter=1;

  # Get the number of authors passed in the $r hash
  # Please note that these authors are ACIS-generated identifiers
  my $total_authors=scalar(keys %{$authors->{'w'}});


  # For each author in the generated authors...
  foreach my $author (keys %{$authors->{'w'}}) {
    # Check the time limit
    if(($INIT_TIME - time) >= $TIME_LIMIT) {
      if(not $TIMEOUT) {
        warn("Time limit of $TIME_LIMIT seconds exceeded by the network exploration - ending the exploration.\n");
        $TIMEOUT=1;
      }
      last;
    }


    # Start with a distance of 0
    $dist=0;

    $MAX_DEPTH=0;

    # Clear the results for vert_go_further_from
    # 10/31/11 If this is cleared, then why is it passed as a parameter?
    $r=undef;

    # Manually set $r to reflect that the $author is 0 steps from itself.
    $r->{'p'}->{$dist}->{$author}=$author;

    # 11/17/11
    # $r->{'p'} is the predecessor(sp? sleep-deprived) of the author for a given distance
    # Values for relationships between AuthorClaim authors are calculated, and then stored into this hash structure
    # Why wouldn't it be faster to calculate these in a more "dynamic" manner?


    # To give a visualization of the completion of vema exploration.
    print("Processing author $author...\n") if $VERBOSE;   
    print("Author $author_counter of $total_authors.\n") if $VERBOSE;

    # Reformatted, more legible
    # if ($VERBOSE > 0) { print("Processing author $author...\n"); }
    # if ($VERBOSE > 0) { print("Author $author_counter of $total_authors.\n"); }

    # The weight of an edge.
    my $weight;

    # To give a visualization of the completion of vema exploration.
    my $aunex_counter=1;

    # THIS IS WHERE THE RECORD TYPE CREATES A PROBLEM

    # 11/19/11
    # I believe that this is purely diagnostic, and worthwhile only for the purposes of printing to a log file
    my $total_aunexes=scalar(keys %{$authors->{'w'}->{$author}});
    my $total_nodes=$total_aunexes;


    # 11/19/11
    # This should throw an exception, rather than simply die
    if(not $total_authors) {
      warn("error in authors structure\n");
      exit;
    }

    # 11/19/11
    # Again, this is a convoluted approach
    # These hash structures should be refined or avoided!

    # foreach my $initialAunexNode (getAllAunexesForAuthor($author))

    # For each initial aunex for the initial author of the tree...
    foreach my $initialAunex (keys %{$authors->{'w'}->{$author}}) {

      # 11/19/11
      # This code is repeated: it should be a function
      # Check the time limit
      if(($INIT_TIME - time) >= $TIME_LIMIT) {
        if(not $TIMEOUT) {
          warn("Time limit of $TIME_LIMIT seconds exceeded by the network exploration - ending the exploration.\n");
          $TIMEOUT=1;
        }
        last;
      }

      # Set the distance to 0.
      $dist=1;

      # 11/19/11
      # This should raise an exception
      $MAX_DEPTH=$dist if $dist > $MAX_DEPTH;
      # if($dist > $MAX_DEPTH) { $MAX_DEPTH = $dist; }

      # To give a visualization of the completion of vema exploration.

      print "Found primary aunex $initialAunex for $author...\n" if $VERBOSE;
      print "Primary aunex $aunex_counter of $total_aunexes for author $author_counter of $total_authors.\n" if $VERBOSE;

      # if ($VERBOSE > 0) { print("Found primary aunex $initialAunex for $author...\n"); }
      # if ($VERBOSE > 0) { print("Primary aunex $aunex_counter of $total_aunexes for author $author_counter of $total_authors.\n"); }

      # Manually set $r to reflect that the $initialAunex is 1 step from $author.
      $r->{'p'}->{$dist}->{$initialAunex}=$author;

      # Unlike with &find_aunexes_for_aun, this structure (produced by &find_aun_for_auth_texts) produced by does yield the Newman-style weights for each edge.

      # Transfer the edge weight to $r from $authors.
      $authors->{'w'}->{$author}->{$initialAunex} ? $r->{'w'}->{$author}->{$initialAunex}=$authors->{'w'}->{$author}->{$initialAunex} : $r->{'w'}->{$author}->{$initialAunex}=0;

      # $weight=$authors->{'w'}->{$author}->{$initialAunex};
      

      # $r->{'w'}->{$author}->{$initialAunex}=$weight if $weight;
      # if($weight > 0) { $r->{'w'}->{$author}->{$initialAunex}=$weight; }
      
      # If the edge weight passed by $authors <= 0, warn the user and exit the script.
#      else {
#        warn("WARNING: Could not find edge weight for $author and $initialAunex.\n");
#        exit;
#      }

      &store_vema_values($initialAunex, $author, $dist, $r, $g_collec_vema);

      # 11/19/11
      # There is no possible means by which to determine the furthest depth of the tree explored because we have not fully explored the tree.

      ####################
      
      # DIAGNOSTIC FEATURE - furthest_depth

      ####################

      if(not $g_dry_run) {
       
        if($MAX_DEPTH <= $g_maxd and not $MAX_DEPTH_explored) {
        
          $g_noma_db=&AuthorProfile::Common::open_db($g_noma_db_file);
          my $noma_record=&AuthorProfile::Common::get_from_db_json($g_noma_db,$author);
          $noma_record->{'furthest_depth'}=$MAX_DEPTH;
          #        my $ended_calc_time=time();
          #        $noma_record->{'ended_calculation'}=$ended_calc_time;
          &AuthorProfile::Common::put_in_db_json($g_noma_db,$author,$noma_record);
          &AuthorProfile::Common::close_db($g_noma_db);
          
          $g_noma_db=&AuthorProfile::Common::open_db($g_noma_db_file);
          $noma_record=&AuthorProfile::Common::get_from_db_json($g_noma_db,$author);
          
          if($noma_record->{'furthest_depth'} != $MAX_DEPTH or (not exists $noma_record->{'furthest_depth'})) { warn "Corruption in noma database for began_calculation for $author BUT THE CALCULATIONS HAVE BEEN COMPLETED FOR $author to a depth of $g_maxd\n"; }
          
          
          &AuthorProfile::Common::close_db($g_noma_db);
          
          
          undef $noma_record;
          $MAX_DEPTH_explored=1;
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
        my $noma_record=&AuthorProfile::Common::get_from_db_json($g_noma_db,$author);
        
        my $current_t_prog=&find_t_gen_progress($t_gen_progress);
        
        $noma_record->{'t_gen_progress'}=$current_t_prog;
        
        &AuthorProfile::Common::put_in_db_json($g_noma_db,$author,$noma_record);
        &AuthorProfile::Common::close_db($g_noma_db);  
        
        $g_noma_db=&AuthorProfile::Common::open_db($g_noma_db_file);
        $noma_record=&AuthorProfile::Common::get_from_db_json($g_noma_db,$author);
        # This addresses a problem with typecasting in Perl
        if(((($current_t_prog - $noma_record->{'t_gen_progress'}) > 0 and ($current_t_prog - $noma_record->{'t_gen_progress'}) > 0.001) or ($current_t_prog - $noma_record->{'t_gen_progress'}) < -0.001) or (not exists $noma_record->{'t_gen_progress'})) {
          die "Corruption in noma database for t_gen_progress for $author";
        }
        
        &AuthorProfile::Common::close_db($g_noma_db);  
        
        
        undef $noma_record;
      }
      
      #####################


      # The neighbors of a given aunex.
      my $neighbors;

      # The previous aunex at this point in the loop is the initial author (distance 0).
      my $old_aunex->{$dist}=$author;
      $old_aunex->{$dist + 1}=$initialAunex;
      my $old_inner_counter=undef;
      $old_inner_counter->{$dist}=$author_counter;
      $old_inner_counter->{$dist + 1}=$aunex_counter;
      my $old_n_index=undef;
      $old_n_index->{$dist}=$total_authors;
      $old_n_index->{$dist + 1}=$total_aunexes;

      my $stored_neighbors;

      # The first aunex to explore the neighbors of is the initial aunex (dist 1).
      my $aunex=$initialAunex;
      my $i=1;

      # Find the neighbors for the initial aunex.
      $neighbors=&find_aunexes_for_aun($aunex);
      if($neighbors eq 'error') { next; }

      my $probe_dist=$dist + 1;

      if($probe_dist > $MAX_DEPTH) { $MAX_DEPTH = $probe_dist; }


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
        if(($INIT_TIME - time) >= $TIME_LIMIT) {
          if(not $TIMEOUT) {
            warn("Time limit of $TIME_LIMIT seconds exceeded by the network exploration - ending the exploration.\n");
            $TIMEOUT=1;
          }
          last;
        }

        # If $n_aun is undefined within the loop, an error has occurred.
        #DEBUG
        if(not defined($aunex)) {
          warn("\$aunex undefined!");
          if ($VERBOSE > 0) { print(Dumper $probe_dist); }
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
          if(($INIT_TIME - time) >= $TIME_LIMIT) {
            if(not $TIMEOUT) {
              warn("Time limit of $TIME_LIMIT seconds exceeded by the network exploration - ending the exploration.\n");
              $TIMEOUT=1;
            }
            last;
          }




          # If the maximum distance hasn't been reached, increment the distance (as we are about to go further into the network).

          #For visualization of generation progress.
          my $nnum=$inner_counter + 1;
          my $ntot=$n_index;

          # $n_aun__2 is now the neighbor corresponding to the index $i_3 within the neighborhood stored by $neighbors.
          $aunex_probe=$neighbors->{'a'}->{$aunex}->[$inner_counter];



          if ($VERBOSE > 0) { print("generate_vema: Probing $aunex_probe \(neighbor $nnum of $ntot\) for $aunex at distance $probe_dist from $initialAunex \($aunex_counter of $total_aunexes\) from $author \($author_counter of $total_authors\).\n"); }

          # Construct the vema path for $n_aun__2 and store it in the vema database.
          $r=&vert_go_further_from($author, $aunex, $vema, $r, $probe_dist, $aunex_probe, $neighbors, $poma);

          ####################
      
          # DIAGNOSTIC FEATURE - furthest_depth
          
          ####################
          
          if(not $g_dry_run) {
            
            if($MAX_DEPTH <= $g_maxd and not $MAX_DEPTH_explored) {
              
              $g_noma_db=&AuthorProfile::Common::open_db($g_noma_db_file);
              my $noma_record=&AuthorProfile::Common::get_from_db_json($g_noma_db,$author);
              $noma_record->{'furthest_depth'}=$MAX_DEPTH;
              #        my $ended_calc_time=time();
              #        $noma_record->{'ended_calculation'}=$ended_calc_time;
              &AuthorProfile::Common::put_in_db_json($g_noma_db,$author,$noma_record);
              &AuthorProfile::Common::close_db($g_noma_db);
              
              $g_noma_db=&AuthorProfile::Common::open_db($g_noma_db_file);
              $noma_record=&AuthorProfile::Common::get_from_db_json($g_noma_db,$author);
              
              if(($noma_record->{'furthest_depth'} != $MAX_DEPTH) or (not exists $noma_record->{'furthest_depth'})) { warn "Corruption in noma database for began_calculation for $author BUT THE CALCULATIONS HAVE BEEN COMPLETED FOR $author to a depth of $MAX_DEPTH\n"; }
              
              
              &AuthorProfile::Common::close_db($g_noma_db);
              
              
              undef $noma_record;
              $MAX_DEPTH_explored=1;
            }
          }
        
          ####################

          # DIAGNOSTIC FEATURE - Tree generation progress

          ####################

          # t_gen_progress array stores the percentage of the tree that has been generated
          
          # Unique to secondary aunexes - store the progress of the primary aunex loop
          
          my $null_var=0;
          
          if($null_var) {
            
            $g_noma_db=&AuthorProfile::Common::open_db($g_noma_db_file);
            my $noma_record=&AuthorProfile::Common::get_from_db_json($g_noma_db,$author);
            
            my $current_t_prog=&find_t_gen_progress($t_gen_progress);
            
            $noma_record->{'t_gen_progress'}=$current_t_prog;
            
            &AuthorProfile::Common::put_in_db_json($g_noma_db,$author,$noma_record);
            &AuthorProfile::Common::close_db($g_noma_db);  
            
            $g_noma_db=&AuthorProfile::Common::open_db($g_noma_db_file);
            $noma_record=&AuthorProfile::Common::get_from_db_json($g_noma_db,$author);
            
            if(((($current_t_prog - $noma_record->{'t_gen_progress'}) > 0 and ($current_t_prog - $noma_record->{'t_gen_progress'}) > 0.001) or ($current_t_prog - $noma_record->{'t_gen_progress'}) < -0.001) or (not exists $noma_record->{'t_gen_progress'})) {
              print Dumper ($current_t_prog - $noma_record->{'t_gen_progress'});
              die "Corruption in noma database for t_gen_progress for $author";
            }
            
            &AuthorProfile::Common::put_in_db_json($g_noma_db,$author,$noma_record);
            &AuthorProfile::Common::close_db($g_noma_db);  
            
            
            undef $noma_record;
          }
          
          #####################


          # Continue exploring further if the maximum distance has yet to be reached.
          if($probe_dist < $g_maxd) {

            # Check the time limit
            if(($INIT_TIME - time) >= $TIME_LIMIT) {
              if(not $TIMEOUT) {
                warn("Time limit of $TIME_LIMIT seconds exceeded by the network exploration - ending the exploration.\n");
                $TIMEOUT=1;
              }
              last;
            }

            # ...set the structure $new_neighbors to the $neighbors of the current secondary aunex...
            $new_neighbors=&find_aunexes_for_aun($aunex_probe);
            if($new_neighbors eq 'error') { next; }

            # Check to see if $n_aun__2 is an isolated aunex.
            if(not keys %{$new_neighbors->{'w'}}) {
              # If so, move to the next secondary aunex that isn't isolated.

              if ($VERBOSE > 0) { print("generate_vema: Skipping isolated neighbor $aunex_probe...\n"); }
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

            if($probe_dist > $MAX_DEPTH) { $MAX_DEPTH = $probe_dist; }

            if ($VERBOSE > 0) { print("generate_vema: Exploring the neighbors for $aunex_probe...\n"); }

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

        if ($VERBOSE > 0) { print("The inner loop has finished for the exploration of neighbors lying one step away from $aunex \(which is a distance of $probe_dist from $author\).\n"); }
        next;
      }
#####################################################################
      if ($VERBOSE > 0) { print("Finished exploring all neighbors for $initialAunex\n"); }
      $aunex_counter++;
      next;
    }
#####################################################################
    if ($VERBOSE > 0) { print("Finished exploring all aunexes for author $author.\n"); }
    $author_counter++;
    next;
  }
#####################################################################
  return $vema;
}

1;
