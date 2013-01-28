#!/usr/bin/python

import signal
from os import getppid,kill
from time import sleep
from multiprocessing import Pool,Process,Event,JoinableQueue
from Queue import Queue


def proc(q):
    #print 'hello', name
    #e=Event()
    #print 'started'
    #p.join()
    #e.set()
    print q.get()
    q.task_done()
    

if __name__ == '__main__':
    q=JoinableQueue()
    print q.__dict__
    map(q.put,['alpha','beta','delta'])
    #p=Pool(3)
    #p.map(f,[q])
    for i in range(3):
        Process(target=proc,args=[q]).start()
    q.join()

