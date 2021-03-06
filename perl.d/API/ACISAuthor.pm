package ACISAuthor;

use strict;
use XML::LibXML;

use lib qw(/home/aupro/ap/perl/lib);

use AMFAuthor;
use Node;
our @ISA=qw( AMFAuthor Node );

use ACISshortid;
use AuthorProfile::Common qw(json_retrieve);
use Neighborhood;

# Debug
use Data::Dumper;

sub new {

  # Require a path to the AMF-XML file in order to construct an ACISAuthor object.
  my $class=shift;
  
  my $self = $class->SUPER::new(shift, # filePath
                                shift  # AMFXMLRootElement
                               );

  $self->{'shortid'}=shift;
  my $shortidStr=shift;

  if($shortidStr and not $self->{'shortid'}) {
    $self->{'shortid'}=new ACISshortid $shortidStr;
  }

  if(not $self->{'shortid'}) {

    # Ensure that there are no errors parsing the XML file.
    my $AMFshortidElement;
    # Assumes that the first element returned is the correct element
    eval { $AMFshortidElement=$self->{'AMFXMLRootElement'}->getElementsByTagNameNS('http://acis.openlib.org','shortid')->[0]; };
    if($@) {
      warn "Warning: Could not parse the ACIS record file $self->{'filePath'}: ",$@;
      bless $self,$class;
      return $self;
    }

    # Ensure that there are no errors instantiating shortid
    my $shortid;
    eval { $shortid = new ACISshortid 0,0,0,$AMFshortidElement; };
    if($@) {
      warn 'Warning: Could not create construct the ACISshortid object for author ',$AMFshortidElement->textContent,$@;
      bless $self,$class;
      return $self;
    }
    $self->{'shortid'}=$shortid;
  }

  bless $self,$class;
  return $self;
}

sub findLocalNeighborhood {

  my $self=shift;

  # To be implemented: Check to see if the local neighborhood has been found

  my $xpc = XML::LibXML::XPathContext->new;
  $xpc->registerNs('amf', 'http://amf.openlib.org');

  # Instantiate a new neigborhood from an array of AMF-XML Elements

#  foreach (map $xpc->findnodes('amf:hasauthor/amf:person',$_),$xpc->findnodes('amf:person/amf:isauthorof/amf:text',$self->{'AMFXMLRootElement'})) {
#    print Dumper new Neighborhood 0,0,0,$_;
#  }
#  die;

# Temp disabled
  my @persons=map $xpc->findnodes('amf:hasauthor/amf:person',$_),$xpc->findnodes('amf:person/amf:isauthorof/amf:text',$self->{'AMFXMLRootElement'});

  return new Neighborhood 0,0,0,\@persons;

#  return new Neighborhood 0,0,0,[map $xpc->findnodes('amf:hasauthor/amf:person',$_),$xpc->findnodes('amf:person/amf:isauthorof/amf:text',$self->{'AMFXMLRootElement'})];

  die;

  return Neighborhood::new map $xpc->findnodes('amf:hasauthor/amf:person',$_),$xpc->findnodes('amf:person/amf:isauthorof/amf:text',$self->{'AMFXMLRootElement'});

  # To do: Remove all below

  foreach (map $xpc->findnodes('amf:hasauthor/amf:person',$_),$xpc->findnodes('amf:person/amf:isauthorof/amf:text',$self->{'AMFXMLRootElement'})) {
    print $_->toString,"\n\n";
  }

  die;

  # Deprecated approach
  my @AMFTextElements;
  eval { @AMFTextElements=$self->{'AMFXMLRootElement'}->getChildrenByTagName('person')->[0]->getChildrenByTagName('isauthorof'); };
  if($@) {
    warn "Warning: ACIS record file for $self->{'shortid'} contains no records for texts accepted by the author.\n";
    next;
  }

  foreach (@AMFTextElements) {

    # Failed attempt at resolving an XPath
    # my $xpc = XML::LibXML::XPathContext->new;
    # $xpc->registerNs('acis', 'http://acis.openlib.org');
    foreach ($_->getChildrenByTagName('text')->[0]->getChildrenByTagName('hasauthor')) {
      # AMF <person> is used to construct the AMFAunex class
      print $_->firstChild->toString,"\n\n";
    }
  }

  # return (new Neighborhood (map (new AMFAuthor, XPath)))

  return 0;
}

# This resolves whether or not the author is registered with ACIS or not
# This needs to be moved into ACISAuthor and AMFAunex (?)
sub resolve {

  my $self=shift;

  my $AMFXMLPersonElement=shift;
  die 'here';
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
