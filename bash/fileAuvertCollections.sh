#!/bin/bash

AMF_COLL_ROOT_PATH=$HOME'/ap/amf/3lib'

nohup nice -n20 $HOME/ap/python/bin/fileAuvertCollections.py -p2 -x$HOME/var/auvert/excluded.txt > $HOME/var/log/auvert/auvertd.`date +%s`.log 2>&1 &