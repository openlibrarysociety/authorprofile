#!/bin/bash

nohup nice -n20 $HOME/python/verticald.py >$HOME/var/log/verticald/`date +%s`.log 2>&1 &