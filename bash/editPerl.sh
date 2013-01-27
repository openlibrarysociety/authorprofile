#!/bin/bash

# 01/07/12 - James
# Copies the Perl script/module, opens it for editing

if [[ ! $1 ]] || [[ ! -f $1 ]] ; then
    echo "Usage: $0 [PERL SCRIPT PATH]"
    exit 1
fi

# BACKUP_PATH=echo "$1" | sed s/\.pl/\.1\.pl/
BACKUP_PATH=$1
BACKUP_PATH=${BACKUP_PATH/\.pl/\.1\.pl}
BACKUP_PATH=${BACKUP_PATH/\.pm/\.1\.pm}
expr "$BACKUP_PATH" : '.\+\.p[lm]$' # if it neither ends with '.pl' nor '.pm', append a '1'
exit 1
expr "$BACKUP_PATH" : '.+\.(pl)(pm)$'
#if [[ $(expr "$BACKUP_PATH"
exit 1
echo $BACKUP_PATH
exit 1
BACKUP_PATH=echo "$BACKUP_PATH" | sed s/\.pm/\.1\.pm/

echo "$BACKUP_PATH" | egrep '\.pl$'
if [[ $? -ne 0 ]] ; then
    BACKUP_PATH=$BACKUP_PATH'.1'
fi

echo "$BACKUP_PATH"



