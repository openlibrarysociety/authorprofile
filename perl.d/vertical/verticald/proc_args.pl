#!/usr/bin/perl

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

1;
