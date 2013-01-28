use strict;
use warnings;

package AMFAunex;

use AMFAuthor;
use Node;
our @ISA = qw( AMFAuthor Node );

sub new {

  my $class=shift;

  my $self = {'nameStr' => shift};
  
  bless $self,$class;
  return $self;
}

1;
