#!/usr/bin/perl

use strict;
use warnings;

package Edge;

sub new {

  my $class=shift;

  my $self={'initialNode' => shift,
            'terminalNode' => shift,
            'weight' => shift
           };

  if(not $self->{'weight'}) {

    
    return 0;
  }

  bless $self,$class;
  return $self;
}

1;
