#!/usr/bin/perl

use strict;
use warnings;

# Common to all AuthorProfile scripts
use lib qw( /home/aupro/ap/perl/lib/ );
use AuthorProfile::Conf;

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

use Data::Dumper;
use Date::Format;
use Encode;
use Proc::ProcessTable;
use utf8;
use XML::LibXML;
binmode(STDOUT,"utf8");

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw( $DEBUG $VERT_LOG_PATH $VERT_BIN_PATH $VERBOSE $COLL @AUTHORS );

# Global Constants

our $DEBUG=0;
our $VERT_LOG_PATH="$home_dir/ap/var/log/vertical";

if(not -d $VERT_LOG_PATH) {
  `mkdir $VERT_LOG_PATH` or die "Fatal error: Could not create directory $VERT_LOG_PATH.\n";
}

our $VERT_BIN_PATH="$home_dir/ap/perl/bin/generate_vid.pl";
my $g_delay=300;
my $g_maxd=5;
our $VERBOSE=1;
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

our @AUTHORS;

### MongoDB Globals
our $COLL;

eval { $COLL=AuthorProfile::Common::get_mongodb_collection('noma'); };
if($@) {
  die "Fatal Error: Could not connect to authorprofile.noma: $!";
}
###

1;
