#!/usr/bin/python

import signal
from os import getppid,kill
from time import sleep
from multiprocessing import Pool,Process,Event

def proc(e):

    print 'testing'
    #while not e.is_set():
        #print 'checking...'
    #print getpid()
    #print 'killing'
    #kill(getppid(),signal.SIGKILL)
    #print 'set'
    #sleep(3)

def f(name):
    #print 'hello', name
    e=Event()
    p=Process(target=proc,args=[e])
    p.start()
    print 'started'
    p.join()
    e.set()

if __name__ == '__main__':
    p=Pool(1)
    p.map(f,['alpha'])
