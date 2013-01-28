package AuthorProfile::Vertical;

use strict;
use warnings;

use lib qw( /home/aupro/ap/perl/lib /home/aupro/usr/lib/perl );
use AuthorProfile::Conf;
use AuthorProfile::Common qw(get_mongodb_collection);

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(
                  $DEBUG
                  $VERT_LOG_PATH
                  $VERT_BIN_PATH
                  $VERBOSE
                  $COLL
                  @AUTHORS
                  $VERT_PROCS
                  $MAX_VERT_PROCS
                  $DELAY
                  $MAX_DIST
                  $LAST_CHANGE_PATH
                  $EDGES_FILE_PATH
                  $STORE_EDGES
                  $VEMA_DB_DIR
                  $VEMA_DB_FILE
                  $NOMA_DB_DIR
                  $NOMA_DB_FILE
                  $REGEN_AUMA
               );

# Global Constants

our $DEBUG=0;
our $VERT_LOG_PATH="$home_dir/ap/var/log/vertical";

if(not -d $VERT_LOG_PATH) {
  `mkdir $VERT_LOG_PATH` or die "Fatal error: Could not create directory $VERT_LOG_PATH.\n";
}

our $VERT_BIN_PATH="$home_dir/ap/perl/bin/vertical/vertical.pl";
our $VERBOSE=3;

# Establish the connection with the MongoDB collection for the noma
our $COLL;
eval { $COLL=AuthorProfile::Common::get_mongodb_collection('noma'); };
if($@) {
  die "Fatal Error: Could not connect to authorprofile.noma: $!";
}


our $DELAY=300;
our $MAX_DIST=5;
# The number of instances of the vertical integration data calculation scripts running on the server.
our $VERT_PROCS=0;
# The maximal amount of instances that the vertical integration data calculation script is permitted to run (given the resources of the server).
our $MAX_VERT_PROCS=1;
our @AUTHORS;
our $LAST_CHANGE_PATH="$home_dir/ap/var/last_change.json";

our $EDGES_FILE_PATH="$home_dir/ap/var/vertical_edges.json";
our $STORE_EDGES=0;

our $VEMA_DB_DIR="$home_dir/ap/var/vertical";

if(not -d $VEMA_DB_DIR) {
  `mkdir -p $VEMA_DB_DIR` or die $!;
  # if(not -d $VEMA_DB_DIR) { die "Fatal Error: Could not create $VEMA_DB_DIR!"; }
}

our $VEMA_DB_FILE="$VEMA_DB_DIR/vema.db";

our $NOMA_DB_DIR="$home_dir/ap/var/vertical";

if(not -d $NOMA_DB_DIR) {
  `mkdir -p $NOMA_DB_DIR` or die $!;
  # if(not -d $VEMA_DB_DIR) { die "Fatal Error: Could not create $VEMA_DB_DIR!"; }
}

our $NOMA_DB_FILE="$NOMA_DB_DIR/noma.db";

our $REGEN_AUMA;


# These are probably deprecated.
my $g_child_procs=undef;
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


#eval { $COLL=AuthorProfile::Common::get_mongodb_collection('noma'); };
#if($@) {
#  die "Fatal Error: Could not connect to authorprofile.noma: $!";
#}
###

1;
