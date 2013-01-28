#!/bin/bash

if [[ ! $2 ]] ; then
    echo "Usage: $0 [ADMIN ACCOUNT USER NAME] [ADMIN ACCOUNT PASSWORD]"
    exit 1
fi

mongo admin --eval\
"db.addUser(\"$1\", \"$1\");
db.auth(\"$2\")"

exit 0