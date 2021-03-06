#!/usr/bin/perl

use strict;
use warnings;

package AMF;

use XML::LibXML;

# Debug
use Data::Dumper;

sub new {

  my $class=shift;
  
  my $self = {filePath => shift,
              # XML root element
              AMFXMLRootElement => shift
             };

  if(not $self->{'AMFXMLRootElement'} and $self->{'filePath'}) {

    # Ensure that there are no errors parsing the XML file.
    my $AMFRootElement;
    eval { $AMFRootElement=XML::LibXML->load_xml(location => $self->{'filePath'})->documentElement; };
    if($@) {
      warn "Warning: Could not parse the ACIS record file $self->{'filePath'}: ",$@;
      bless $self,$class;
      return $self;
    }
    
    $self->{'AMFXMLRootElement'}=$AMFRootElement;
  }

  bless $self,$class;
  return $self;
}

1;
