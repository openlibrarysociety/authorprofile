#!/usr/bin/php
<?
## print "hello world\n";
$profile_file='/home/aupro/ap/opt/amf/3lib/am/j/e/pje1.amf.xml';
$doc=DOMDocument::load($profile_file );
$is_authorof_list=$doc->getElementsByTagName('isauthorof');
$author_of=$is_authorof_list->length;
print "he has $author_of papers\n";
## list the name
## list all texts
## list all accepted text
#print $doc->saveXML($first_text);
?>