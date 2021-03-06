package AMFAuthor;

use strict;

use AMF;
our @ISA=('AMF');

# Debug
use Data::Dumper;

sub new {

  my $class=shift;

  my $self = $class->SUPER::new(shift, # filePath
                                shift # XML root element
                               );

  # For instances where the object is instantiated from the AMF-XML <person> element
  $self->{'AMFXMLPersonElement'}=shift;


  bless $self,$class;
  return $self;
}

sub getAttr {
  my ($self,$attrName)=@_;
  return $self->{$attrName} if exists $self->{$attrName};
}

sub findTree {

  # The order is as follows:
  # Get the neighboring aunexes (primary aunexes, which are the initial aunexes relative to the initial author)
  # This returns the primary neighborhood (the initial neighborhood relative to the initial author)
  # From this neighborhood, generate the tree
  # By generating the tree from this neighborhood, edges between the root node and the 'primary node' are created
  # Foreach/For iterative loop
  # From these edges, paths are created from the root node to the neighboring node
  # Foreach/For iterative loop
  # Now, the tree object can be constructed
  # Then, explore the tree to a certain depth
  # While iterative loop
  # Cache minimally (all nodes, paths, edges, and neighborhood instantiated outside of the primary neighborhood will be deleted when no longer needed)
  # If the distance of the path generated between the root node and the terminal neighbor isn't the maximum depth...
  # ...the get the neighboring aunexes for the initial neighbor...
  # ...and the initial neighbor becomes the primary node
  # For each node neighboring the primary node...
  # Find the path between the root node and the node neighboring the primary node...
  # Once the iteration is finished, check distance between the root node and the terminal node
  # If it's below the maximum depth, loop
  # If it meets the maximum depth, clear all paths, edges, nodes for the neighborhood
  # Clear the neighborhood itself
  # Get the next path generated for the last neighborhood
  # If there are no more paths, climb further down the tree
  # If this leads to the last path of the primary neighborhood, then the tree has been explored
  # If not, continue, iterate

  my ($self,$maxDepth)=@_;
  
  return 0;
}

1;
