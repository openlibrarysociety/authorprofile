#!/usr/bin/perl

use strict;
use warnings;

package Path;

use Edge;

sub new {
  my $class=shift;

  my $self = {'edges' => shift,
              'length' => shift,
              'nodes' => shift,
              'weight' => shift
             };

  bless $self,$class;
  return $self;
}

1;
