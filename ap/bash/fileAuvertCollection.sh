#!/bin/bash

# 01/07/12 - James
# Auvert a single AMF collection

if [[ ! $1 ]] ; then
    echo "Usage: $0 [AMF COLLECTION]"
    exit 1
fi

nohup nice -n20 $HOME/ap/perl/bin/fileAuvertCollection.pl $1 >$HOME/var/log/auvert/`date +%s`.log 2>&1 &
