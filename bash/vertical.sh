#!/bin/bash

if [[ ! $2 ]] || [[ ! -f $1 ]] ; then
    echo "Usage: $0 [ACIS PROFILE PATH] [MAXIMUM DEPTH]"
    exit 1
fi

AUTHOR_NAME=${1//\/*\//}
AUTHOR_NAME=${AUTHOR_NAME%*.*.*}

nohup nice -n20 $HOME/ap/perl/bin/vertical/vertical.pl --maxd=$2 $1 >$HOME/var/log/vertical/`date +%s`.$AUTHOR_NAME.log 2>&1 &