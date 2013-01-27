#!/usr/bin/perl

package ACISshortid;

use strict;
use warnings;

# To be implemented
# Will be a base class containing filePath, AMFXMLRootElement attributes
# our @AMF::ISA=('AMFobject');

use XML::LibXML;

sub new {

  my $class=shift;
  
  my $self = {'shortidStr' => shift,
              'filePath' => shift,
              'AMFXMLRootElement' => shift,
              'AMFXMLshortidElement' => shift
             };

  # If the shortid string has been passed...
  if($self->{'shortidStr'}) {

    # ...and if no other arguments have been passed...
    if(not $self->{'filePath'}) {

      my $ACISDirPath='/home/aupro/ap/amf/3lib/am';
      # Inefficient
      my $ACISshortidStem=$self->{'shortidStr'};
      $ACISshortidStem=~s/^p//;
      # Needs to trim all numeric characters
      $ACISshortidStem=~s/.$//;
      my $ACISFilePath="$ACISDirPath/" . join('/',split(//,$ACISshortidStem)) . "/$self->{'shortidStr'}.amf.xml";
      if(not -f $ACISFilePath) {

        warn "Could not locate file $ACISFilePath for $self->{'shortidStr'}";
        bless $self,$class;
        return $self;
      }
      $self->{'filePath'}=$ACISFilePath;
    }

    # If the AMF-XML <amf> element has not been passed...
    if(not $self->{'AMFXMLRootElement'}) {
     
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
  }

  # If the ACIS shortid string was not passed...
  if(not $self->{'shortidStr'}) {

    # ...but the AMF-XML <acis:shortid> element was...
    if($self->{'AMFXMLshortidElement'}) {

      my $shortidStr;
      eval { $shortidStr=$self->{'AMFXMLshortidElement'}->textContent; };
      if($@) {
        # Fix: This should be a file name
        warn 'Warning: Could not retrieve the ACIS shortid string for the file ',$self->{'AMFXMLshortidElement'}->documentElement->textContent,$@;
        bless $self,$class;
        return $self;
      }

      $self->{'shortidStr'}=$shortidStr;

      # Address this: Need eval {}'s
      $self->{'AMFXMLRootElement'}=$self->{'AMFXMLshortidElement'}->ownerDocument->documentElement;
      $self->{'filePath'}=$self->{'AMFXMLshortidElement'}->ownerDocument->URI;
    }
  }

  bless $self,$class;
  return $self;
}

1;
