#!/usr/bin/perl

use strict;
use warnings;

package Neighborhood;

use AMFAuthor;
use AMFAunex;
use ACISAuthor;
use XML::LibXML;

use Data::Dumper;

sub resolve {

  my $AMFXMLPersonElement=shift;

  # Check the navama
  my $navamaPath='/home/aupro/ap/var/navama.json';
  my $navama;
  eval { $navama=AuthorProfile::Common::json_retrieve($navamaPath); };
  if($@) {
    die "Fatal: Could not retrieve the 'navama'";
  }

  if(exists $navama->{$AMFXMLPersonElement->firstChild->textContent}) {
    # print "Resolved author ",$navama->{$AMFXMLPersonElement->firstChild->textContent},"\n";
    return new ACISAuthor 0,0,0,$navama->{$AMFXMLPersonElement->firstChild->textContent};
  }

  print "Resolved aunex ",$AMFXMLPersonElement->firstChild->textContent,"\n";
  return new AMFAunex $AMFXMLPersonElement->firstChild->textContent;

  # Check the name variations database
  # If the name variation exists in the database, obtain the short ID, and search for the ACISAuthor object
  # If the ACISAuthor object exists, return it
  # If not, instantiate the ACISAuthor object, and return it
  # This is why it might be necessary to restructure this approach:
  # AMFAuthor cannot use a class which, itself, implements AMFAuthor as a base class (infinite recursion)
  # The method, then, would be ACISAuthor::resolve AMFAuthor
  # If it is not registered, then it will return AMFAunex
}

sub new {

  my $class=shift;

  my $self = {
              'authorNodes' => shift,
              'args' => shift,
              'edges' => shift,
              'AMFXMLPersonElements' => shift
             };

  if($self->{'args'}) {
    
    if(exists $_->{'filter'}) {
      
      print "Filter is",$_;
    }
  }

  # We cannot find the edges without first finding the nodes  
  if(not $self->{'authorNodes'}) {


    # Instantiate AMFAuthor objects from AMF-XML <person> elements
    # We cannot determine whether or not this <person> element references an identified author
#    eval { @authorNodes=map new AMFAuthor,$self->{'AMFXMLPersonElements'}; };
#    if($@) {
#      warn "Warning: Could not find the author nodes for the neighborhood\n";
#      bless $self,$class;
#      return $self;
#    }

#    foreach ($self->{'AMFXMLPersonElements'}) {
#      print Dumper;
#    }

    # No need to create AMFAuthor objects - just use ACISAuthor::resolve
    my @authorNodes;
    eval { @authorNodes=map { resolve($_); } @{$self->{'AMFXMLPersonElements'}}; };
    if($@) {
      warn "Warning: Could not find the author nodes for the neighborhood\n";
      bless $self,$class;
      return $self;
    }
    $self->{'authorNodes'}=\@authorNodes;
  }

  if(not $self->{'edges'}) {
    print 'test';
  }

  bless $self,$class;
  return $self;
}


1;
