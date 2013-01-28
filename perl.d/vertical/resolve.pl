#!/usr/bin/perl

use strict;
use warnings;

use lib qw( /home/aupro/ap/perl/lib );
use AuthorProfile::Common qw( json_retrieve );
use XML::LibXML;
use ACISAuthor;
use AMFAunex;

sub resolve {

  my $AMFXMLPersonElement=shift;

  # print $self->toString;
  print $AMFXMLPersonElement->toString;

  # Check the navama
  my $navamaPath='/home/aupro/ap/var/navama.json';
  my $navama;
  eval { $navama=AuthorProfile::Common::json_retrieve($navamaPath); };
  if($@) {
    die "Fatal: Could not retrieve the 'navama'";
  }

  if(exists $navama->{$AMFXMLPersonElement->firstChild->textContent}) {
    print "resolved author\n";
    return new ACISAuthor 0,0,0,$navama->{$AMFXMLPersonElement->firstChild->textContent};
  }

  print "resolved aunex\n";
  return new AMFAunex $navama->{$AMFXMLPersonElement->firstChild->textContent};

  # Check the name variations database
  # If the name variation exists in the database, obtain the short ID, and search for the ACISAuthor object
  # If the ACISAuthor object exists, return it
  # If not, instantiate the ACISAuthor object, and return it
  # This is why it might be necessary to restructure this approach:
  # AMFAuthor cannot use a class which, itself, implements AMFAuthor as a base class (infinite recursion)
  # The method, then, would be ACISAuthor::resolve AMFAuthor
  # If it is not registered, then it will return AMFAunex
}

1;
