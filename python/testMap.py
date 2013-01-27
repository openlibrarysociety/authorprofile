#!/usr/bin/python

from multiprocessing import Pool
from time import sleep, time
from random import randint

def f(x):
    sleep(x)
    print 'finished at',time(),'for',x,'seconds'
    #return x*x

i=0
while i < 2:
    if __name__ == '__main__':
        pool = Pool(processes=3)
    #result = pool.apply_async(f, [10])
    #print result.get(timeout=1)
    # print pool.map(f, [5,0.1,0.1])
        pool.map_async(f, [0.2,10,0.1,0.1]).wait()
        pool.close()
        pool.join()
        print 'finished at iteration',i
    i+=1
