#!/usr/bin/perl

use strict;
use warnings;

package Tree;

sub new {
  my $class=shift;

  my $self={
            'rootNode' => shift,
            'neighborhoods' => shift,
             'depth' => shift,
            # Paths are composed of edges
             'paths' => shift,
             'nodes' => shift
            };

  # Neighborhoods have the attribute primaryAuthorNode
  # Currently, have currentNode,previousNode,previousNeighborhood
  # Retrieving with just Node
  # Could Node have localNeighborhoods?
  # Node->{localNeighborhoods}
  # Neighborhoods are indexed in the following manner:
  # Tree->{'neighborhoods'}[distanceFromRootNode]->{primaryAuthorNodeOfParentNeighborhood}->{parentNeighborhood}=Neighborhood
  # Thus, for the initial neighborhood of a Tree:
  # Tree->{'neighborhoods'}[1]->{0}->{0}=initialNeighborhood
  # In order to retrieve a Neighborhood at a distance of 2 from 'pkr1'
  # Tree->{'neighborhoods'}[2]->{rootNode}->{initialNeighborhood}=manyNeighborhoods

  bless $self,$class;
  return $self;
}

1;
