#!/usr/bin/python

import sys
#from os import stat,kill,getppid
import os
import time
import multiprocessing
from multiprocessing import Pool,Process,Event,JoinableQueue
from lxml import etree
from pymongo import *
from bson.code import Code
from threading import BoundedSemaphore,Lock
import re
import subprocess
from time import time,sleep
import signal

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

TIME_LIMIT_ALL_AUTHORS=7*24*60*60 # One week
TIME_LIMIT_ONE_AUTHOR=24*60*60 # One day

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

def getSortedAuthorRecordsForConditions(collName,conditions,sortValue,whereValue=None):

    #CONDITION1='began_calculation':{'$exists':False},'ended_calculation':{'$exists':False}
    #SORT_VALUES=[('last_change_date',DESCENDING),('began_calculation',ASCENDING)]

    findCondition={'author':{'$exists':True}}
    for condition in conditions:
        findCondition.update(condition)

    print findCondition
    authorRecords=[]
    conn=getMongoDBConn()

    nomaCursor = getMongoDBColl(DB_NAME,NOMA_COLL_NAME,conn).find(findCondition,sort=[sortValue])

    print 'found'+str(nomaCursor.count())+'records'

    if whereValue:
        print 'filtered'+str(nomaCursor.count())+'records'
        nomaCursor=nomaCursor.where(whereValue)

    print 'sorted'+str(nomaCursor.count())+'records'
    for nomaRecord in nomaCursor.sort('furthest_depth'):

        authorRecords.append(nomaRecord)
    conn.disconnect()

    return authorRecords

    ####

    #conn=getMongoDBConn()
    #nomaCursor = getMongoDBColl(NOMA_DB_NAME,NOMA_COLL_NAME,conn).find({'author':{'$exists':True},'began_calculation':{'$exists':False},'ended_calculation':{'$exists':False}},sort=[('last_change_date',1)])
    
    #for nomaRecord in nomaCursor.sort('furthest_depth'):
        #authorRecords.append(nomaRecord)
    #conn.disconnect()

    ###

    #conn=getMongoDBConn()
    #nomaCursor = getMongoDBColl(NOMA_DB_NAME,NOMA_COLL_NAME,conn).find({'author':{'$exists':True},'began_calculation':{'$exists':True},'ended_calculation':{'$exists':False}},sort=[('began_calculation',1)])

    #for nomaRecord in nomaCursor.sort('began_calculation'):
        #authorRecords.append(nomaRecord)
    #conn.disconnect()

    ###

    #conn=getMongoDBConn()
    #nomaCursor = getMongoDBColl(NOMA_DB_NAME,NOMA_COLL_NAME,conn).find({'author':{'$exists':True},'$where':"this.began_calculation > this.ended_calculation"},sort=[('began_calculation',1)])

    #for nomaRecord in nomaCursor.sort('began_calculation'):
        #authorRecords.append(nomaRecord)
    #conn.disconnect()

    #conn=getMongoDBConn()
    #nomaCursor = getMongoDBColl(NOMA_DB_NAME,NOMA_COLL_NAME,conn).find({'author':{'$exists':True},'$where':"this.began_calculation < this.ended_calculation"},sort=[('ended_calculation',1)])
    #for nomaRecord in nomaCursor:
        #if not (nomaRecord['author'] in authorIDs):
            #authorIDs.append(nomaRecord['author'])
    #conn.disconnect()

    #pass

# Not well-written, no clean code ; tired, will address later
def getSortedAuthorIDs():

    print str(time())+': Retrieving the sorted author ID\'s...'
    #authorIDs=[]
    authorRecords=[]

    # TO DO: Retrieve the value for furthest_depth, and then iterate (which each query specifying the depth)
    # This will allow sorting first by furthest_depth, then by other factors

    # 01/21/12 - James
    # I've made this the priority for new authors
    # Retrieve the authors for whom there is no last vertical integration data
    # Sort by the last_change_date

    #CONDITION1='began_calculation':{'$exists':False},'ended_calculation':{'$exists':False}
    #SORT_VALUES=[('last_change_date',DESCENDING),('began_calculation',ASCENDING)]
        
    # Authors without vertical integration records
    records=getSortedAuthorRecordsForConditions(NOMA_COLL_NAME,[{'began_calculation':{'$exists':False}},{'ended_calculation':{'$exists':False}}],('last_change_date',1))
    for record in records:
        #if record not in authorRecords:
        record['furthest_depth']=3
            #print record
        authorRecords.append(record)
    records=None


    # Authors for whom the first calculations did not finish
    records=getSortedAuthorRecordsForConditions(NOMA_COLL_NAME,[{'began_calculation':{'$exists':True}},{'ended_calculation':{'$exists':False}}],('began_calculation',1))
    for record in records:
        #if record not in authorRecords:
        record['furthest_depth']=3
            #print record
        authorRecords.append(record)
    records=None

        # ... for whom the last calculations didn't finish
    records=getSortedAuthorRecordsForConditions(NOMA_COLL_NAME,[],('began_calculation',1),Code("this.began_calculation > this.ended_calculation"))
    #for record in records:    
    #    if record not in authorRecords:
    #        authorRecords.append(record)
    authorRecords.extend(records)
    records=None

        # ... for whom the last calculations did finish
    records=getSortedAuthorRecordsForConditions(NOMA_COLL_NAME,[],('ended_calculation',1),Code("this.began_calculation < this.ended_calculation"))
    #for record in records:
    #    if record not in authorRecords:
    #        authorRecords.append(record)
    authorRecords.extend(records)

    return authorRecords


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

def checkLogModTime(logPath,author,verticalProc):

    while not verticalProc.poll():
        if os.path.exists(logPath) and (time() - os.stat(logPath).st_mtime > (5*60)): # If the vertical process has been inactive for more than 5 minutes...
            print 'Vertical calculations for',author,'stopped responding.  Killing process...'
            verticalProc.terminate() # ...kill the process
            return
        sleep(5*60) # Check every 5 minutes

def getVertical(q):

    authorRecord=q.get() # Retrieve the author record from the queue
    print str(time())+': Initiating vertical calculation process for '+authorRecord['author']

    logPath=os.environ['HOME'] + '/var/log/vertical/' + authorRecord['author'] + '.' + str(time()) + '.log'
    logFile=open(logPath,'a+')
    #logFile=open(os.environ['HOME'] + '/var/log/vertical/' + authorRecord['author'] + '.' + str(time()) + '.log','a+')
    verticalProc=subprocess.Popen(["nohup","nice","-n20",VRT_BIN_PATH,"--maxd=3",getACISProfilePath(authorRecord['author'])],stdout=logFile,stderr=subprocess.PIPE)
    timerProcess=Process(target=checkLogModTime, args=[logPath,authorRecord['author'],verticalProc])
    timerProcess.start()
    verticalProc.wait()
    logFile.close()
    timerProcess.terminate()

    
    #try:


        # Deprecated
        #finished=Event() # This signals the timer process that the vertical process has finished

        #if ONLY_3_DEPTH:

            #verticalProc=subprocess.Popen(['perl','-e',"print \"Perl: testing...\n\";sleep(30);print \"Perl: finished\n\""])
            #verticalProc=subprocess.Popen(['perl','-e',"print \"Perl: testing\n\""])



        #else:
            #subprocess.call(["nohup","nice","-n20",VRT_BIN_PATH,"--maxd="+str(getMaxDepthForAuthor(author) + 1),getACISProfilePath(author)],stdout=logFile,stderr=subprocess.PIPE)


    #except:

        #print 'Error: system execution of',VRT_BIN_PATH,'failed for',authorRecord['author']
        #return 1

    q.task_done()

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

        authors=getSortedAuthorIDs()
        q=JoinableQueue()

        for i,j in zip(range(0,len(authors)-MAX_PROCS,MAX_PROCS+1),range(MAX_PROCS,len(authors),MAX_PROCS+1)):
            map(q.put,authors[i:j])
            for author in authors[i:j]:
                Process(target=getVertical,args=[q]).start()
            q.join()

        if(len(authors)-1) % 2:
            map(q.put,authors[-MAX_PROCS-1:])
            for author in authors[-MAX_PROCS-1:]:
                Process(target=getVertical,args=[q]).start()
            q.join()

        if not DEBUG:

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
        #pass
