#!/usr/bin/perl

use lib qw(/home/mamf/lib/perl);
use CGI::Fast qw/-utf8/;
use FCGI;
use Data::Dumper;

#use CGI::Application;
use Carp::Assert;

use threads;

use AuthorProfile::Web;

sub start_caching {
  print("Running caching thread.\n");
  return 0;
}

sub check_cache {
  return 0;
}

#my $app = new AuthorProfile::Web(QUERY => $q);

$caching_thr=threads->create({'scalar' => 1}, \&start_caching);
$caching_thr->detach();

#  $check_cache_thr=threads->create({'scalar' => 1}, \&check_cache);
#  $check_cache_thr->detach();

#my $request=FCGI::Request();



#while (my $q = new CGI::Fast) {
#while($request->Accept() >= 0) {

#    print("Running fcgi.\n");
#}
