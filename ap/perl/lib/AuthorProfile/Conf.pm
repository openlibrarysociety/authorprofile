package AuthorProfile::Conf;

use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(
                  $home_dir
                  $home_ap_dir
                  $auvert_dir
                  $noma_db_file
                  $doc_dir
                  $style_dir
                  $xslt_dir
                  $html_dir
                  $ap_dir
                  $xml_dir
                  $auma_file
                  $navama_file
                  $poma_file
                  $ap_top_xsl_file
                  $amf_ns
                  $acis_ns
                  $ap_ns
                  $vema_db_file
                  $last_change_file
                  $threelib_dir
               );

## directories
our $home_dir='/home/aupro';
our $home_ap_dir="$home_dir/ap";
our $auvert_dir="$home_ap_dir/amf/auverted";
our $xslt_dir="$home_ap_dir/style";
our $html_dir="$home_ap_dir/html";
our $ap_dir="$home_ap_dir/amf/3lib/am";
our $xml_dir="$home_ap_dir/var/xml";
our $style_dir="$home_ap_dir/style";
our $doc_dir="$home_ap_dir/doc";
our $threelib_dir="$home_ap_dir/amf/3lib";

## files 
our $noma_db_file="$home_ap_dir/var/noma.db";
our $vema_db_file="$home_ap_dir/var/vema.db";
our $auma_file="$home_ap_dir/var/auma.json";
our $navama_file="$home_ap_dir/var/navama.json";
our $poma_file="$home_ap_dir/var/poma.json";
our $last_change_file="$home_ap_dir/var/last_action.json";
our $ap_top_xsl_file="$home_ap_dir/style/profile.xslt.xml";

## namespaces
our $amf_ns='http://amf.openlib.org';
our $acis_ns='http://acis.openlib.org';
our $ap_ns='http://authorprofile.org';


## cheers!
1;
