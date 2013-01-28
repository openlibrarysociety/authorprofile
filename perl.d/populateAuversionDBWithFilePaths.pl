#!/usr/bin/perl

use strict;
use warnings;

use AuthorProfile::Auvert qw(auvert_file_life
                             auvert_dir
                             process_in_file_time_start
                             process_in_file_time_end
                             mark_all_files_as_processed
                             fileAuvertFile
                           );
use AuthorProfile::Common qw(get_mongodb_collection);

use Data::Dumper;
use List::Util 'shuffle';
binmode(STDOUT,"utf8");


my $VERBOSE=1;


my $home_dir=$ENV{'HOME'};

my $input_dir="$home_dir/ap/amf/3lib/";



my $COLL_DIR=$ARGV[0] or warn 'No collection name passed';



#my $in_dir;

# hal iucr finished
my @COLLECTIONS=qw(am dmf citeseerxpsu we hal iucr);



sub processCollections {

  foreach my $collectionPath (shuffle(`ls $input_dir`)) {

    chomp $collectionPath;



    if(not grep{$_ eq $collectionPath}@COLLECTIONS) {
      print $collectionPath."\n";
      
      my $in_dir=$input_dir.$collectionPath;
      # Process the directory (formerly process_dir)
      if((-d $in_dir) and grep $in_dir,shuffle(`find $input_dir -maxdepth 1 -type d`)) {
        
        print "processing $in_dir...\n" if $VERBOSE;
        my @files = shuffle(`find $in_dir -name '*.amf.xml'`);
        if(not @files) {
          
          foreach my $subdir (`find $in_dir -type d`) {
            chomp $subdir;
            next if $subdir eq $in_dir;
            process_dir($subdir);
          }
        }
        foreach my $file (@files) {
          
          chomp $file;
          my $cursor=eval{AuthorProfile::Common::getMongoDBAuProRecord('auversion',undef,{'filePath' => {'$exists' => 1}})};
          if($@) {
            warn "Could not query the MongoDB server: $!";
            next;
          }
          my @records=$cursor->next;
          next if @records;
          print 'found unprocessed file';
          exit;
        }
      }
      
      print time.': finished for collection '.$collectionPath."\n";
    }
  }
}
processCollections;
