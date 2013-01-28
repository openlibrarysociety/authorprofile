#!/bin/bash

nohup nice -n20 $HOME/python/horizontal.py > $HOME/var/log/horizontal/`date +%s`.log 2>&1 &