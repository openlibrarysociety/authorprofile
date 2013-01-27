#!/usr/bin/perl

use strict;
use warnings;

package Node;

use Tree;

sub new {
  my $class=shift;
  
  # Abstract
  my $self={};

  bless $self,$class;
  return $self;
}

1;
