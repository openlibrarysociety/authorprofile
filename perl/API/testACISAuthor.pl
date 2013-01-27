#!/usr/bin/perl

use strict;
use warnings;

use ACISAuthor;

use Data::Dumper;

#my $author2 = new ACISAuthor 0,0,0,'pkr1';
# print Dumper $author2;

#die;

my $pkrPath='/home/aupro/ap/amf/3lib/am/k/r/pkr1.amf.xml';

my $author = new ACISAuthor $pkrPath;

# print Dumper $author;
my $n=$author->findLocalNeighborhood;
print Dumper $n->{'authorNodes'};
# print $author->getAttr('AMFXMLRootElement')->toString;
