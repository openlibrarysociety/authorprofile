#!/usr/bin/perl

use strict;
use warnings;

require 'proc_args.pl';

sub proc_input {
  @args=shift;
  foreach my $input_var (@args) {
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

1;
