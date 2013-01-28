#!/usr/bin/perl

use lib qw( /home/aupro/ap/perl/lib /home/aupro/usr/lib/perl );

use strict;
use File::Temp qw(tempdir); 

use BerkeleyDB;
use AuthorProfile::Conf;
use Mamf::Common qw(integrate_file integrate_dir);
use AuthorProfile::Auvert qw(auvert_file_life 
                             auvert_dir 
                             process_in_file_time_start
                             process_in_file_time_end
                             mark_all_files_as_processed
                             fileAuvertFile
                           );
use AuthorProfile::Common qw(get_mongodb_collection);

use Data::Dumper;

## run parameter: do clean up of /tmp/, set to 0 or 1

my $VERBOSE=1;

## Global constants
my $home_dir=$ENV{'HOME'};
my $ap_dir="$home_dir/ap/amf/auverted";
my $input_dir="$home_dir/ap/amf/3lib/";

binmode(STDOUT,"utf8");

my $COLL_DIR=$ARGV[0] or die 'No collection name passed';
my @INCOMPLETE_FILES;

# Auvert the unprocessed files first
my $cursor=AuthorProfile::Common::getMongoDBAuProRecord('auversion',undef,{'lastAuversionSuccessful' => 0,'amfCollection' => $COLL_DIR});
$cursor->sort({'timeLastAuverted' => 1});
my @records=$cursor->next;
my @INCOMPLETE_FILES;
foreach my $incompleteFileRecord (@records) {

  my $incompleteFile=$incompleteFileRecord->{'filePath'};
  print 'Auversion for '.$incompleteFile." did not finish.\n";
  push @INCOMPLETE_FILES,$incompleteFile;
  fileAuvertFile($input_dir.$incompleteFile,$COLL_DIR);
}

my $in_dir=$input_dir.$COLL_DIR;

# Process the directory (formerly process_dir)
if((-d $in_dir) and grep $in_dir,`find $input_dir -maxdepth 1 -type d`) {

  print "processing $in_dir...\n" if $VERBOSE;
  my @files = `find $in_dir -name '*.amf.xml'`;
  if(not @files) {

    foreach my $subdir (`find $in_dir -type d`) {
      chomp $subdir;
      next if $subdir eq $in_dir;
      process_dir($subdir);
    }
  }
  foreach my $file (@files) {

    print "processing $file\n" if $VERBOSE;
    chomp $file;
    my $cursor=AuthorProfile::Common::getMongoDBAuProRecord('auversion',undef,{'filePath' => $file,'lastAuversionSuccessful' => 1});
    my @records=$cursor->next;
    if(@records) {

      print "$file was already auverted\n";
      next;
    }
    next if grep($file,@INCOMPLETE_FILES);
    fileAuvertFile($file,$COLL_DIR);
  }
}
else {

  die "Fatal: Collection $COLL_DIR could not be found";
}
