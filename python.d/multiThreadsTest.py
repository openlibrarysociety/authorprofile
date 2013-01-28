#!/usr/bin/python

import signal
from os import getpid,kill
from time import sleep
from multiprocessing import Process,Event,Queue,Pool

# Queue isn't in parallel
# If worker B hangs before worker A, but the single watcher process is monitoring worker A, then worker B remains hung
# Need to spawn separate watcher processes for each vertical process

# authors=getSortedAuthorIDs()
# q=Queue()
# for i,j in zip(range(len(authors)-MAX_PROCS),range(MAX_PROCS,len(authors))):
#    p=Process(...)
#    p.start()
#    map(q.put,authors[i:j])
#    q.join()
# ...
# def getVertical(q):
#    ...
#    authorRecord=q.get()
#    ...
#    q.task_done()

def proc(q):

    pid=getpid()
    
    print str(pid)+': retrieving from queue...'
    m=q.get()
    print str(pid)+': retrieved',m

    # while not finished.is_set():
        # if(time() - stat(logPath)['stat_mtime'] < 300):
            # timing out due to log modification inactivity
            # kill (m[1],signal.SIGKILL)
        # sleep(300)

    print 'killing...'
    kill(m[1],signal.SIGKILL)


def f(null):

    print 'worker process: putting into queue...'
    q.put(['testing',getpid()])
    print 'worker process: sleeping...'
    sleep(5)
    
q=Queue()

print 'spawning process...'
p=Process(target=proc,args=[q])
p.start()

pool=Pool(2)
print 'spawning workers...'
pool.map(f,[None,None])

