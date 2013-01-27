#!/usr/bin/perl

use strict;
use warnings;
use lib qw( /home/aupro/ap/perl/lib /home/aupro/usr/lib/perl );

use AuthorProfile::Conf;
use AuthorProfile::Vertical;
require 'header.pl';
require 'create_vema_db.pl';
require 'create_noma_db.pl';
# Need to fix
require 'vertical.pl';


sub proc_args {

  my $input_var=shift;

##################################
# Exact string comparisons
##################################

  # Deprecated: This is a default setting.
#  if($input_var eq '--no-edges') {
#    $STORE_EDGES=0;
#    return;
#  }

  if($input_var eq '--store-edges') {
    $STORE_EDGES=1;
    return;
  }

  if($input_var eq '--forced-auma-regen') {
    $REGEN_AUMA=1;
    return;
  }
  if($input_var eq '-q' or $input_var eq '--quiet') {
    $VERBOSE=0;
    return;
  }
  if($input_var eq '--dry-run') {
    $DEBUG=1;
    return;
  }
  if($input_var eq '--width-priority') {
    # $g_width_p=1;
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
    if($VERBOSE) { print "Vertical database file set to $vema_db_file\n"; }
    # return &create_vema_db($vema_db_file);
    return;
  }

  if($input_var=~m|--diagnostics-database=|) {
    my $noma_db_file=$input_var;
    $noma_db_file=~s|--diagnostics-database=||;
    if(not -f $noma_db_file) {
      $noma_db_file=~s|^~|$home_dir|;
      if(not -f $noma_db_file) {
        warn("File $noma_db_file doesn't exist!\n");
        return;
      }
    }
    if($VERBOSE) { print "Diagnostics database file set to $noma_db_file\n"; }
    # &create_noma_db($noma_db_file);
    return;
  }

  if($input_var=~m|--maxd=|) {
    my $maxd=$input_var;
    $maxd=~s|--maxd=||;
    if(not $maxd) {
      warn("No maximum distance passed!\n");
      return;
    }
    $MAX_DIST=$maxd;
    return;
  }
  if($input_var=~m|-d|) {
    my $maxd=$input_var;
    $maxd=~s|-d||;
    if(not $maxd) {
      warn("No maximum distance passed!\n");
      return;
    }
    if($VERBOSE) { print "Maximum distance set to $maxd\n"; }
    $MAX_DIST=$maxd;
    return;
  }
  if($input_var=~m|-n|) {
    my $maxn=$input_var;
    $maxn=~s|-n||;
    if(not $maxn) {
      warn("No maximum distance passed!\n");
      return;
    }
    if($VERBOSE) { print "Node limit set to $maxn nodes\n"; }
    # $g_max_nodes=$maxn;
    return;
  }
  if($input_var=~m|--time-limit=|) {
    my $maxt=$input_var;
    $maxt=~s|--time-limit=||;
    if(not $maxt) {
      warn("No time limit passed!\n");
      return;
    }
    if($VERBOSE) { print "Time limit set to $maxt seconds\n"; }
    # $g_time_limit=$maxt;
    return;
  }
  if($input_var=~m|-t|) {
    my $maxt=$input_var;
    $maxt=~s|-t||;
    if(not $maxt) {
      warn("No time limit passed!\n");
      return;
    }
    if($VERBOSE) { print "Time limit set to $maxt seconds\n"; }
    # $g_time_limit=$maxt;
    return;
  }

##################################

  warn("Unrecognized argument '$input_var' passed - ignoring this!\n");
  return;
}

1;
