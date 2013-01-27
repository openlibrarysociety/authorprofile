#!/usr/bin/perl

use warnings;
use strict;

use MongoDB;

MongoDB::Connection->new->get_database('test')->get_collection('test')->update({'alpha' => 'beta'},{'$set' => {'delta' => 'gamma'}},{'upsert' => 1});
