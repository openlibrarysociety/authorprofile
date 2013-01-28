#!/usr/bin/perl

use strict;
use warnings;

my $VERTICALD_PATH="$ENV{'HOME'}/ap/perl/bin/vertical/verticald";
require "$VERTICALD_PATH/proc_args.pl";

sub proc_input {
  foreach my $input_var (@ARGV) {
    &proc_args($input_var);
  }
}

1;
