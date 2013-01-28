#!/usr/bin/perl

use strict;
use warnings;

use Proc::ProcessTable;

#sub refresh_vert_procs_running {
sub getRunningVerticalInstances {

  my $t = new Proc::ProcessTable;
  my @vert_pids;
  
  # First obtain the pid's of all running instances of the vertical script...
  foreach my $p (@{$t->table}) {
    if(($p->{'fname'} eq 'vertical.pl')) {
      print "Found an instance of the vertical script with a process ID of $p->{'pid'} running.\n" if $VERBOSE;
      push(@vert_pids, $p->{'pid'});
    }
  }
  
  # ...and then obtain the authors for which the vertical integration data is currently being calculated.
  my $running_authors;
  my @runningAuthors;
  
  foreach my $vert_pid (@vert_pids) {
    foreach my $p (@{$t->table}) {
      if($p->{'pid'} eq $vert_pid) {
        # This is tedious simply due to the impossibility of clearly distinguishing flags and options from filenames on the command line invocation of the vertical script.
        my $vert_options=$p->{'cmndline'};
        $vert_options=~s|/usr/bin/perl||;
        $vert_options=~s|/home/aupro/ap/perl/bin/vertical.pl||;
        my $running_author=$vert_options;
        $vert_options=~s|/home/aupro/ap/amf/3lib/am/.*$||;
        $vert_options=~s|^\s*||;
        $vert_options=~s|\s*$||;
        
        $running_author=~s|/home/mamf/opt/amf/3lib/am/||;
        $running_author=~s|.amf.xml||;
        $running_author=~s|././||;
        $running_author=~s|\Q$vert_options\E||;
        $running_author=~s|^\s*||;
        
        # If there are already instances of the vertical script running for this author $running_author, issue a warning to STDERR.

        if(grep { $_ eq $running_author } @runningAuthors) {
          warn "Warning: More than one instance of the vertical script found to be running for $running_author!\n" if $VERBOSE;
          next;
        }

        push @runningAuthors,$running_author;
      }
    }
  }
  return @runningAuthors;
}

1;
