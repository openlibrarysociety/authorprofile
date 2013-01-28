#!/usr/bin/perl

use strict;
use warnings;

use lib qw( /home/aupro/ap/perl/lib /home/aupro/usr/lib/perl );

use Data::Dumper;
use AuthorProfile::Common qw( add_status
                              open_db 
                              close_db
                              json_store
                              json_retrieve
                              put_in_db_json
                              get_from_db_json
                              get_root_from_file );


use AuthorProfile::Conf;
use Encode;
use utf8;

binmode(STDOUT,"utf8");

# Global variables
my $g_debug=0;
my $g_verbose=0;
my $g_input;
my $hid_db_file="$home_dir/ap/var/hid.db";

sub proc_args {

  my $input_var=shift;

##################################
# Exact string comparisons
##################################

  if($input_var eq '-D' or $input_var eq '--debug') {
    $g_debug=1;
    return;
  }

  if($input_var eq '-q' or $input_var eq '--quiet') {
    $g_verbose=0;
    return;
  }

##################################
# Regexp operations
##################################

  if($input_var=~m|--horizontal-database=|) {
    $hid_db_file=$input_var;
    $hid_db_file=~s|--horizontal-database=||;
    if(not -f $hid_db_file) {
      $hid_db_file=~s|^~|$home_dir|;
      if(not -f $hid_db_file) {
        warn("File $hid_db_file doesn't exist!\n");
        return;
      }
    }

    if($g_verbose) { print "HID database file set to $hid_db_file\n"; }

    return;
  }

##################################

  warn("Unrecognized argument '$input_var' passed - ignoring this!\n");
  return;
}

sub proc_input {
  foreach my $input_var (@ARGV) {
    if(not defined($g_input)) {
      if(-f $input_var or -d $input_var) {
        $g_input=$input_var;
        next;
      }
      else {
        &proc_args($input_var);
      }
    }
  }
}

#####################################################

# The Main function of the script


sub main {
  &proc_input();
  
  reduce_aunex('James Robert Griffin Powers');

}

sub reduce_aunex {
  my $aunex=shift;
  print "starting with $aunex...\n";

#  foreach my $subnames (scalar(split(' ',$aunex))) {
#    $

#  print Dumper split(' ',$aunex);
#  $aunex=~s|\.||g;
  $aunex=~s| |_|g;
  my $longest=$aunex;
  $longest=~s|\.||g;
  print "the longest variant: $longest\n";

  my @subnames=split('_',$aunex);
  
  # Hash for abbreviations
  my $h_abbrev;
  # Hash for initials
  my $h_inits;
  my $shortest_nvar;
  my $h_prefixes;
  my $h_suffixes;

  my $i=0;

  # To do: Investigate whether or not this is a prefix

  if(exists $h_prefixes->{0}) {
    $shortest_nvar.=$subnames[0] . '_';
    $i=1;
  }

  # DEBUG
#  $h_suffixes->{$#subnames}=1;
  
  if(keys %{$h_suffixes}) {
    for(my $j = $#subnames - 1; $j > 0; $j--) {
      #Check for other suffixes
    }
  }


  # If substring contains more than one '.', it is likely to be a prefix/suffix
  # e.g. M.D.
  # If substring contains one '.' but more than one alphabetical character, it is likely to be a prefix/suffix
  # e.g. Ph._D.
  # Case should also be taken into account here
  # e.g. Note that all alpha chars in 'M.D.' are in the upper case

  # Ambiguity: Roman numerals and initials.
  # 'I' could be an initial without proper punctuation.
  # 'Ii' and "Iii' could represent certain non-Western names.
  # 'VI': e.g. 'Lenin VI'

  # No choice but to leave it to the user to disambiguate
  # Offer both:

  # J. R. G. I. and J. R. G. III
  # Griffin, J. R., III and Iii, J. R. G. (take case into account)

  # Crude algorithm:
  # If potential suffix exceeds 1 character and subnames exceeds 3...
  # It is likely that this is a Roman numeral

  # M. P. D. II is far more likely to be Michael Phillips Dawson II than Mikhail P. D. I. Ilyanov
  # Still, however, the option should be offered.

  # For the sake of functionality, this should take into account the very unlikely event of multiple prefixes.  This is last priority, however.

  # Do not reduce the initial and terminal substrings (prefixes and suffixes).
  for($i; $i < $#subnames; $i++) {
#    print $subnames[$i],"\n";
 
    if($subnames[$i]=~m|\.|g) {
      $h_abbrev->{$i}=1;
    }

    my $subname=$subnames[$i];
    $subname=~s|\.||g;

#    die Dumper $h_suffixes;

    if(length($subname) == 1) {
      $h_inits->{$i}=1;
    }
    if(exists $h_inits->{$i} or exists $h_suffixes->{$i}) {
      $shortest_nvar.=$subname . '_';
    }
    else {
      $shortest_nvar.=substr($subname,0,1) . '_';
    }
  }

  if(exists $h_inits->{$i} or exists $h_suffixes->{$i}) {
    $shortest_nvar.=$subnames[$#subnames];
  }
  else {
    $shortest_nvar.=substr($subnames[$#subnames],0,1);
  }

  # To do: Investigate whether or not this is a suffix
#  $shortest_nvar.=$subnames[$#subnames];
  print "the shortest variant: $shortest_nvar\n";


  my @bases=split('_',$shortest_nvar);

  # This is produced by removing the number of prefixes and suffixes which
#  aren't reduced
  my $const_1 = $#subnames;
  my @subnames_2=@subnames;
  my @subnames_3=@subnames;

  my @oldnames;

  my $h_names;

  my $first_base='';
  my $second_base='';

  my $aunexvar='';

  my $w=$#bases;

  for(my $z=0;$z <= $#bases;$z++) {
    my $y;



    # Print any preceding initials
    for($y=0;$y < $z;$y++) {
      $first_base.=$bases[$y];
    }
#    print $first_base,"\n";
    $aunexvar=$first_base;
    print $aunexvar,"\n";
#    <SDDIN>;
    undef $first_base;
    # Print the subname
#    print $subnames[$z];
    $aunexvar.=$subnames[$z];
    print $aunexvar,"\n";
    <STDIN>;

    my $x;

    for($x=$z + 1;$x <= $w;$x++) {
#      print $subnames[$x];
      $aunexvar.=$subnames[$x];
    }
    print $aunexvar,"\n";
    <STDIN>;
#    die;
    for($w++;$w <= $#bases;$w++) {
      # Print any proceeding initials following the last subnames printed
      $second_base.=$bases[$w];
    }
    $w--;
#    print "second: $second_base\n";
    $aunexvar.=$second_base;
    print $aunexvar,"\n";
    #      undef $aunexvar,$first_base,$second_base;
#    print "\n";
  }
  exit;
#######
  for(my $k=0; $k < $const_1; $k++) {
    my $subname_1;
    foreach my $oldname (@oldnames) {
      $subname_1.=$oldname;
    }
    $subname_1.=$subnames[$k];

    for(my $l=0; $l < $const_1; $l++) {

      foreach my $base (@bases) {
        $subname_1.=$base;
      }
      print $subname_1,"\n";
      pop @bases;
      
#      print $subname_1 . $short_base[$l + 1] . $short_base[$l + 2],"\n";

    }

    push@oldnames,$subnames[$k];

  }

#  print Dumper $h_names;

  return 0;
}

main;
