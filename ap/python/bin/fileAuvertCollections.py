#!/usr/bin/python

import sys
import os
import time
import multiprocessing
from multiprocessing import Pool
from lxml import etree
from pymongo import *
from threading import BoundedSemaphore
import re
import random

AUVERT_BIN_PATH=os.environ['HOME'] + '/ap/bash/fileAuvertCollection.sh'

MAX_PROCS=1
cpuCount = multiprocessing.cpu_count()
if cpuCount > 2:
    MAX_PROCS=cpuCount - 1

DEBUG = False

def auvertColl(coll):
    try:
        # os.system('/bin/echo '+coll)
        os.system(AUVERT_BIN_PATH + ' ' + coll)
    except:
        print 'Error: system execution of',AUVERT_BIN_PATH,'failed for',coll
        return 1

    return 0

def getColls(amfCollRootPath): # Get a list of all of the files contained in a collection

    if not re.search('/$',amfCollRootPath): # Fix the trailing slash
        amfCollRootPath+='/'

    if not os.path.isdir(amfCollRootPath):
        print 'Warning: A file path',amfCollRootPath,'was passed for a directory path.'
        # 09/24/11 Minor adjustment necessary
        # return [amfCollRootPath]
        return []

    try:
        os.listdir(amfCollRootPath)
    except:
        print 'Warning: Directory path',amfCollRootPath,'could not be opened.' # Should be throwing an exception
        # 09/09/11: This is creating the problem.  The value 1 is being passed as a parameter to the auvertColl function.  Should have the auvertColl return a value of 1 immediately if it is not passed a valid file path.
        # return collFiles
        # 09/15/11: For the sake of convenience, I'm simply returning an array with a single element
        # This isn't the proper way to implement this, but I'm short on time
        # return collFiles.append(amfCollRootPath) # This returns None?
        # 09/24/11 Minor adjustment necessary
        # return [amfCollRootPath]
        return [] # Treat the problematic path like a file

    colls=[]

    for coll in os.listdir(amfCollRootPath): # For each child directory/file/node within a child dir/file/node...
        collPath = amfCollRootPath + coll # ...first transform the relative path into the absolute path...
        if not (collPath in EXCLUDEPATHS or (collPath + '/') in EXCLUDEPATHS) and os.path.isdir(collPath): # ...and if it is a subdirectory...
            colls.append(coll) # ...and append all results to the array.
    # At the moment, I'm having difficulty restricting the number of processes generated by an invocation for a Perl script within Python
    # This is a horribly inefficient, but temporary, solution to the problem
    random.shuffle(colls)
    # TO DO: From here, the MongoDB should be queried, and the list should be sorted
    # e. g. The collection last auverted should be appended last to the list, the newest collection should receive the highest priority, etc.
    return colls[0:MAX_PROCS]
    #return colls


def auvertColls(amfCollRootPath):

#    if not re.search('/$',collPath):
#        collPath+='/'

    if not os.path.isdir(amfCollRootPath):
        print "Error:",collPath,"is not a valid collection directory path."
        exit(1)

    if __name__ == '__main__': # Auvert the files
        
        # There is a formula for designating the proper number of processes to generate given the number of cores available
        # This should be properly implemented, but I simply wanted to get the script working
        # An alternative approach might be to use Jython and utilize Java's own Executor framework (which, I believe, performs these calculations for us)...


        print getColls(amfCollRootPath)
        exit()


        #if DEBUG:
            #pool = Pool(processes=MAX_PROCS)
            #pool.map(auvertColl, getColls(amfCollRootPath),1)
            #exit(0)

        # Limiting the performance on holda
        MAX_PROCS=2

        try:
            pool = Pool(processes=MAX_PROCS)
            
        except:
            print 'Fatal Error: Could not instantiate a Pool object'
            exit(1)

        try:
            pool.map(auvertColl, getColls(amfCollRootPath))
        except:
            print 'Error: Could not \'auvert\' the collections stored for',amfCollRootPath
            exit(1)
            
        print 'File \'auversion\' finished at',time.time()
        return 0

# Note: This should be a percentage of the maximum connections returned by db.serverStatus()
# I'm unsure as to how exactly we plan on sharing access between the different scripts
# For now, I suppose that we could allow the systems to work on a "first come, first serve" basis
# The scripts could simply loop until a connection is available, and then proceed
# Otherwise, a separate script (or set of scripts) should be used to prioritize access to the MongoDB

try:
    conn = Connection()
    # db = conn['asyncAuvert']
    db = conn['auversion']

except:
    # print 'Error: Could not connect to the database \'asyncAuvert\''
    print 'Error: Could not connect to the database \'auversion\''
    exit(1)

connAvail = 0

try:
    connAvail = db.command('serverStatus')['connections']['available']

except:
    print 'Error: Could not retrieve the number of MongoDB connections available'
    exit(1)
    
mongoSema = BoundedSemaphore(value=(.25 * connAvail)) # Use 25% of the connections available

amfCollRootPath = os.environ['HOME'] + '/ap/amf/3lib/'

# 09/24/11
excludePaths = []
excludePathsList = False
for argV in sys.argv:
    # No "switch(...) { case: [...] }" statements in Python

    argVIndex = sys.argv.index(argV)

    if excludePathsList:

        excludedPath = re.sub('~',os.environ['HOME'],argV)

        if not os.path.isdir(excludedPath):
            print 'Error: Path',excludedPath,'passed as an argument is not a directory path.'
            continue

        excludePaths.append(re.sub('^\-x','',re.sub('^\Q--exclude-path=\E','',excludedPath)))



        if (argVIndex + 1 < len(sys.argv)) and not os.path.isdir(sys.argv[argVIndex + 1]):
            excludePathsList = False

    # Added for "lazy debugging" capabilities
    elif re.search('^\-d',argV):
        DEBUG = True

    # Set the maximum number of processes
    elif re.search('^\-p',argV):

        if re.sub('^\-p','',argV):
            maxProcs=int(re.sub('^\-p','',argV))
        else:
            maxProcs=int(sys.argv[argVIndex + 1])
            sys.argv.remove(sys.argv[argVIndex])

        if maxProcs > 0:
            MAX_PROCS = maxProcs

    # List of directory paths to be excluded
    # Tired - this is probably an inefficient approach
    elif re.search('^\Q--exclude-path=\E',argV) or re.search('^\-x',argV):

        if argV == '--exclude-path=' or argV == '-x':

            excludedPath = re.sub('~','',sys.argv[argVIndex + 1])
            sys.argv.remove(sys.argv[argVIndex])

            if os.path.isdir(excludedPath):
                excludePaths.append(excludedPath)
                excludePathsList = True
                continue

            # List of collection paths to be excluded
            elif os.path.isfile(excludedPath):
                # Open and read from the file
                excludeFH = open(excludedPath)
                for excLine in excludeFH.readlines():
                    # Exclude comments
                    if re.search('^#',excLine):
                        continue
                    excludePaths.append(re.sub(r'\n$','',re.sub('~',os.environ['HOME'],excLine)))
                excludeFH.close()

            else:
                print 'Warning: Bad exclusion argument passed.'
                continue

        excludeArg = re.sub('~',os.environ['HOME'],re.sub('^\-x','',re.sub('^\Q--exclude-path=\E','',argV)))

        if os.path.isdir(excludeArg):
            excludePaths.append(excludeArg)

            if (sys.argv.index(argV) + 1 < len(sys.argv)) and os.path.isdir(sys.argv[sys.argv.index(argV) + 1]):
                excludePathsList = True

        # List of collection paths to be excluded
        elif os.path.isfile(excludeArg):
            # Open and read from the file
            excludeFH = open(excludeArg)
            for excludedPath in excludeFH.readlines():
                # Exclude comments
                if re.search('^#',excludedPath):
                    continue
                excludePaths.append(re.sub(r'\n$','',re.sub('~',os.environ['HOME'],excludedPath)))
            excludeFH.close()

        else:
            if excludeArg:
                print 'Warning: Bad exclusion argument passed:'

    # The path of the collection does not take an "argument prefix keyword"(WC?)
    elif os.path.isdir(argV):
        amfCollRootPath = argV

    else:
        if argVIndex > 0:
            print 'Warning: Non-existent collection path or unknown argument',argV,'passed.'

# Declare the globals for the script

EXCLUDEPATHS = excludePaths
AMFCOLLROOTPATH = os.environ['HOME'] + '/ap/amf/syncAuvert/'

amfAuvOutPath = os.environ['HOME'] + '/ap/amf/syncAuvert/'
# amfAuvOutPath = re.sub('/$','',os.environ['HOME'] + '/ap/amf/asyncAuvert')
# amfAuvOutPath += '/asyncAuvert'

AMFAUVOUTPATH = amfAuvOutPath
exit(auvertColls(AMFCOLLROOTPATH))
