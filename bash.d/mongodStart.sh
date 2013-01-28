#!/bin/bash

# Start the MongoDB daemon

# Using the security features
# mongodInit.sh # Check the admin user account(s) (script under development)
# mongodStop.sh
# nice -n20 mongod --auth --master --dbpath=/home/aupro/ap/data > ~/var/log/mongod/`date +%s`.log 2>&1 &

# Security disabled (for the sake of convenience)
nohup nice -n20 mongod --master --dbpath=/home/aupro/ap/data > $HOME/var/log/mongod/`date +%s`.log 2>&1 &