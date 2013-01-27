#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use MongoDB;
use XML::LibXML;
use XML::LibXSLT;

use lib qw( /home/aupro/ap/perl/lib );
use AuthorProfile::Common qw(load_xslt add_status json_retrieve);

sub insert_record {
  my $coll = shift;
  my $record = shift;
  return $coll->insert($record);
}

my $conn = MongoDB::Connection->new;
my $db = $conn->get_database('auversion');
my $coll = $db->get_collection('asyncAuvert');

my $aunex = 'Marzia Freo';

my $test_record = {
                   aunex => $aunex,
                   updated => 1315177667.259486,
                   xml => "<amf xmlns=\"http://amf.openlib.org\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://amf.openlib.org http://amf.openlib.org/2001/amf.xsd\"><text xmlns=\"http://amf.openlib.org\" id=\"info:lib/RePEc:aaa:wpaper:5\"><title>The impact of sales promotions on store performance: a structural vector autoregressive (SVAR) approach.</title><displaypage>http://econpapers.repec.org/RePEc:aaa:wpaper:5</displaypage><hasauthor><person><name>Marzia Freo</name></person></hasauthor></text><!--RePEc/aaawpaper 1 1315177666.65--><text id=\"info:lib/RePEc:aaa:wpaper:70\"><title>A Comparison of forecasting Volatility startegies into ARCH Class throughPricing</title><displaypage>http://econpapers.repec.org/RePEc:aaa:wpaper:70</displaypage><hasauthor><person><name>Marzia Freo</name></person></hasauthor><!--RePEc/aaawpaper 1 1315177666.86--></text><text id=\"info:lib/RePEc:aaa:wpaper:71\"><title>Analysis of european stock returns: evidence of a new risk factor</title><displaypage>http://econpapers.repec.org/RePEc:aaa:wpaper:71</displaypage><hasauthor><person><name>Riccardo Cesari</name></person></hasauthor><hasauthor><person><name>Marzia Freo</name></person></hasauthor><!--RePEc/aaawpaper 2 1315177666.88--></text><text id=\"info:lib/RePEc:aaa:wpaper:72\"><title>Estimating a stochastic volatility model for DAX-Index options</title><displaypage>http://econpapers.repec.org/RePEc:aaa:wpaper:72</displaypage><hasauthor><person><name>Marzia Freo</name></person></hasauthor><!--RePEc/aaawpaper 1 1315177666.9--></text><text id=\"info:lib/RePEc:aaa:wpaper:76\"><title>Indagine sulle matricole dell'Ateneo di Bologna nell'anno accademico 2001-2002</title><displaypage>http://econpapers.repec.org/RePEc:aaa:wpaper:76</displaypage><hasauthor><person><name>Pinuccia Calia</name></person></hasauthor><hasauthor><person><name>Carlo Filippucci</name></person></hasauthor><hasauthor><person><name>Marzia Freo</name></person></hasauthor><hasauthor><person><name>Giorgio Tassinari</name></person></hasauthor><!--RePEc/aaawpaper 3 1315177666.99--></text><text id=\"info:lib/RePEc:aaa:wpaper:85\"><title>Osservatorio del mercato del lavoro della provincia di Bologna: Rapporto 2006</title><displaypage>http://econpapers.repec.org/RePEc:aaa:wpaper:85</displaypage><hasauthor><person><name>Giorgio Tassinari</name></person></hasauthor><hasauthor><person><name>Furio Camillo</name></person></hasauthor><hasauthor><person><name>Marzia Freo</name></person></hasauthor><hasauthor><person><name>Andrea Guizzardi</name></person></hasauthor><!--RePEc/aaawpaper 3 1315177667.2--></text><text id=\"info:lib/RePEc:aaa:wpaper:86\"><title>Osservatorio del mercato del lavoro della provincia di Bologna: Rapporto primo semestre 2007</title><displaypage>http://econpapers.repec.org/RePEc:aaa:wpaper:86</displaypage><hasauthor><person><name>Giorgio Tassinari</name></person></hasauthor><hasauthor><person><name>Furio Camillo</name></person></hasauthor><hasauthor><person><name>Marzia Freo</name></person></hasauthor><hasauthor><person><name>Andrea Guizzardi; Caterina Liberati</name></person></hasauthor><!--RePEc/aaawpaper 3 1315177667.25--></text></amf>" };

#print Dumper insert_record($coll,$test_record);

my $cursor = $coll->find_one({ aunex => $aunex });
my $xml = $cursor->{'xml'};

my $xslt_dir = $ENV{'HOME'} . '/ap/style';
my $xslts;
$xslts->{'aunex'}=&AuthorProfile::Common::load_xslt("$xslt_dir/aunex.xslt.xml");

my $auma_file= $ENV{'HOME'} . '/ap/var/auma.json';
my $auma=&AuthorProfile::Common::json_retrieve($auma_file);    

my $doc = XML::LibXML->load_xml(
      string => $xml);

my $docRoot = $doc->documentElement();
$docRoot=&AuthorProfile::Common::add_status($docRoot,$auma,$aunex);
my $results = eval { 
  $xslts->{'aunex'}->transform($doc, 'aunex' => "'$aunex'") ;
};

my $output=$xslts->{'aunex'}->output_as_bytes($results);

print $output;
