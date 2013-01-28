#!/usr/bin/python

import signal
from os import getppid,kill
from time import sleep
from multiprocessing import Process,Event

def proc(e):

    while not e.is_set():
        print 'checking...'
    #print getpid()
    #print 'killing'
    #kill(getppid(),signal.SIGKILL)
    print 'set'
    #sleep(3)
    
#print getpid()
e=Event()
p=Process(target=proc,args=[e])
p.start()
print 'setting'
e.set()
sleep(5)
#p.join()


