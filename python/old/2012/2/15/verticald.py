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
import subprocess
from time import time

#VRT_BIN_PATH=os.environ['HOME'] + '/ap/bash/vertical.sh'
VRT_BIN_PATH=os.environ['HOME'] + '/ap/perl/bin/vertical/vertical.pl'

MAX_PROCS=1
cpuCount = multiprocessing.cpu_count()
if cpuCount > 2:
    MAX_PROCS=cpuCount - 1
MAX_PROCS=2

DEBUG = True

DB_NAME='authorprofile'
COLL_NAME='auversion'
VRT_DB_NAME=DB_NAME
VRT_COLL_NAME='vema'
NOMA_DB_NAME=DB_NAME
NOMA_COLL_NAME='noma'

# Debug
NEW_AUTHORS_ONLY=False
INCONSISTENT_RECORDS_ONLY=True
FINAL_ITERATION=True
ONLY_3_DEPTH=True

MAX_RESULTS=5

DRY_RUN=True

def getMongoDBConn():

    try:
        conn=Connection()
    except:
        getMongoDBConn()

    return conn

def getMongoDBColl(dbName,collName,conn):

    try:
        db = conn[dbName]

    except:
        print 'Error: Could not connect to the database',dbName
        exit(1)

    try:
        coll=db[collName]
    except:
        print 'Error: Could not find the collection',collName,'in the database',dbName
        exit(1)

    return coll

# Not well-written, no clean code ; tired, will address later
def getSortedAuthorIDs():

    print str(time())+': Retrieving the sorted author ID\'s...'
    authorIDs=[]

    # TO DO: Retrieve the value for furthest_depth, and then iterate (which each query specifying the depth)
    # This will allow sorting first by furthest_depth, then by other factors

    # 01/21/12 - James
    # I've made this the priority for new authors
    # Retrieve the authors for whom there is no last vertical integration data
    # Sort by the last_change_date
    conn=getMongoDBConn()
    nomaCursor = getMongoDBColl(NOMA_DB_NAME,NOMA_COLL_NAME,conn).find({'author':{'$exists':True},'began_calculation':{'$exists':False},'ended_calculation':{'$exists':False}},sort=[('last_change_date',1)])
    for nomaRecord in nomaCursor:
        if not (nomaRecord['author'] in authorIDs):
            authorIDs.append(nomaRecord['author'])
    conn.disconnect()

    if NEW_AUTHORS_ONLY:
        print str(time())+': Retrieved the author ID\'s for which no vertical integration calculations have been performed, sorted by the time of last ACIS profile modification.'
        return authorIDs

    # Retrieve the authors for whom there is inconsistent vertical integration data

    # Authors for whom the first calculations did not finish
    conn=getMongoDBConn()
    nomaCursor = getMongoDBColl(NOMA_DB_NAME,NOMA_COLL_NAME,conn).find({'author':{'$exists':True},'began_calculation':{'$exists':True},'ended_calculation':{'$exists':False}},sort=[('began_calculation',1)])
    for nomaRecord in nomaCursor:
        if not (nomaRecord['author'] in authorIDs):
            authorIDs.append(nomaRecord['author'])
    conn.disconnect()

    # Authors for whom the last calculations did not finish
    # db.noma.find({$where:"this.began_calculation > this.last_change_date"})
    conn=getMongoDBConn()
    nomaCursor = getMongoDBColl(NOMA_DB_NAME,NOMA_COLL_NAME,conn).find({'author':{'$exists':True},'$where':"this.began_calculation > this.ended_calculation"},sort=[('began_calculation',1)])
    for nomaRecord in nomaCursor:
        if not (nomaRecord['author'] in authorIDs):
            authorIDs.append(nomaRecord['author'])
    conn.disconnect()

    if INCONSISTENT_RECORDS_ONLY:
        return authorIDs


    # Finally, retrieve the authors for whom the last calculations did finish
    conn=getMongoDBConn()
    nomaCursor = getMongoDBColl(NOMA_DB_NAME,NOMA_COLL_NAME,conn).find({'author':{'$exists':True},'$where':"this.began_calculation < this.ended_calculation"},sort=[('ended_calculation',1)])
    for nomaRecord in nomaCursor:
        if not (nomaRecord['author'] in authorIDs):
            authorIDs.append(nomaRecord['author'])
    conn.disconnect()

    # NOTE
    # Due to the difficulty of mapping to an execution of a Perl script, this should NOT return the entire list, but a slice
    # Once finished, this script should invoke the Bash script which invoked this process (psuedo-loop)
    # This behavior should be mimicked by fileAuvertCollections.py / auvertd.py
    # return authorIDs[0:MAX_PROCS]
    return authorIDs

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
AMFCOLLROOTPATH = amfCollRootPath

amfAuvOutPath = os.environ['HOME'] + '/ap/amf/syncAuvert/'
# amfAuvOutPath = re.sub('/$','',os.environ['HOME'] + '/ap/amf/asyncAuvert')
# amfAuvOutPath += '/asyncAuvert'

AMFAUVOUTPATH = amfAuvOutPath
#exit(auvertColls(AMFCOLLROOTPATH))

ACIS_PROFILE_ROOT_PATH=os.environ['HOME'] + '/ap/amf/3lib/am/'

def getACISProfilePath(author):

    # print ACIS_PROFILE_ROOT_PATH + str(map(lambda u: u+'/',re.sub('[1-9]+$','',re.sub('^p','',author)))) + author + '.amf.xml'
    #print ACIS_PROFILE_ROOT_PATH + re.sub('.','\\1\/',re.sub('[1-9]+$','',re.sub('^p','',author))) + author + '.amf.xml'

    # Yes, this is horrible.  Tired, just want this to work.
    authStem=re.sub('[1-9]+$','',re.sub('^p','',author))
    authRelPath=''
    for char in authStem:
        authRelPath+=char
        authRelPath+='/'
    return ACIS_PROFILE_ROOT_PATH + authRelPath + author + '.amf.xml'

def getMaxDepthForAuthor(author):

    conn=getMongoDBConn()
    nomaRecord = getMongoDBColl(NOMA_DB_NAME,NOMA_COLL_NAME,conn).find_one({'author':author,'furthest_depth':{'$exists':True}})
    if nomaRecord:
        depth=nomaRecord['furthest_depth']
    else:
        depth=3
    conn.disconnect()

    return depth

def getVertical(author):

    print str(time())+': Initiating vertical calculation process for '+author

    # 02/14/12
    # Debug
    #if DEBUG:
        #return
    
    try:

        logFile=open(os.environ['HOME'] + '/var/log/vertical/' + author + '.' + str(time()) + '.log','a+')
        if ONLY_3_DEPTH:
            subprocess.call(['nohup',VRT_BIN_PATH,'--maxd=3',getACISProfilePath(author)],stdout=logFile,stderr=subprocess.PIPE)            
        else:
            subprocess.call(["nohup","nice","-n20",VRT_BIN_PATH,"--maxd="+str(getMaxDepthForAuthor(author) + 1),getACISProfilePath(author)],stdout=logFile,stderr=subprocess.PIPE)
        logFile.close()
    except:

        print 'Error: system execution of',VRT_BIN_PATH,'failed for',author
        return 1
    #return True

VRTD_BIN_PATH=os.environ['HOME'] + '/python/verticald.py'

while(True):

    if __name__ == '__main__':

        MAX_PROCS=2

        print str(time())+': Creating the pool of worker threads...'
        try:
            pool = Pool(processes=MAX_PROCS)
        
        except:
            print 'Fatal Error: Could not instantiate a Pool object'
            continue

        try:
            # To do: Use this to log which vertical processes did not finish
            print 'System-wide vertical integration calculations began at',time()
            pool.map_async(getVertical,getSortedAuthorIDs()).wait()
            pool.close()
            pool.join()
            print 'Vertical integration calculations finished at',time()

        except:
            print 'Error: Could not initiate the vertical integration calculations.'

    if FINAL_ITERATION:
        exit()
