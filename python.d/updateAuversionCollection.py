#!/usr/bin/env python

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

DB_NAME='authorprofile'
COLL_NAME='auversion'

AMF_NS={'amf':'http://amf.openlib.org'}
QUERY_LIMIT=100
AMF_AUVERTED_PATH=os.environ['HOME']+'/ap/amf/auverted'

def printUnicodeStr(_str):

    try:
        print str(_str)

    except:
        print 'Error: Could not print unicode string to STDOUT'

    return True


def getMongoDBConn():

    try:
        conn=Connection()
    except:
        print 'Error: Could not connect to the MongoDB server (is it running?)'
        exit(1)

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

def auvertColl(coll):
    try:
        # os.system('/bin/echo '+coll)
        os.system(AUVERT_BIN_PATH + ' ' + coll)
    except:
        print 'Error: system execution of',AUVERT_BIN_PATH,'failed for',coll
        return 1

    return 0

def updateAuversionColl(): # Get a list of all of the files contained in a collection

    conn=getMongoDBConn()
    records=getMongoDBColl(DB_NAME,COLL_NAME,conn).find({'aunex':{'$regex':'^[a-z]*$'},'filePath':{'$exists':1}},limit=QUERY_LIMIT)
    conn.disconnect()
    if not records:
        print 'Warning: No records found in the MongoDB'
        return None
    for record in records:
        if(not record['filePath']) or (not record['aunex']):
            continue
        printUnicodeStr(('Found record for aunex',record['aunex']))
        filePath=AMF_AUVERTED_PATH+'/'+record['filePath']
        try:
            amfDoc=etree.parse(filePath)
        except:
            print 'Error: Could not parse'
            continue
        for amfTextElement in amfDoc.xpath('/amf:amf/amf:text',namespaces=AMF_NS):
            for amfHasAuthorElement in amfTextElement.xpath('amf:hasauthor',namespaces=AMF_NS):
                try:
                    amfNameElement=amfHasAuthorElement.xpath('amf:person/amf:name',namespaces=AMF_NS)[0]
                except:
                    printUnicodeStr(('Warning: Could not find any <name/>\'s in',filePath))
                    next
                printUnicodeStr(('Found AMF name',amfNameElement.text))

                amfName=re.sub('\.','',amfNameElement.text)
                amfName=amfName.lower()

                amfName=amfName.encode('ascii', 'backslashreplace')

                for encChar in re.findall(r'\\x.{2}',amfName):
                    amfName = re.sub('\\' + encChar,('00' + re.sub(r'\\x','',encChar).upper()),amfName)
                for utf8Char in re.findall(r'\\u.{4}',amfName):
                    amfName = re.sub('\\' + utf8Char,(re.sub(r'\\u','',utf8Char).upper()),amfName)
                        
                printUnicodeStr(('Comparing',amfName,'with',record['aunex']))
                if re.search(amfName,record['aunex']):
                    printUnicodeStr(('Inserting auversion record for',amfNameElement.text))
                    conn=getMongoDBConn()
                    try:
                        # .update({'aunex':aunex},{'$set':{'timeLastUpdated':time.time(),'lastUpdateSuccessful':0}},True)
                        getMongoDBColl(DB_NAME,COLL_NAME,conn).update({'aunex':record['aunex']},{'$set':{'aunex':amfNameElement.text}},True)
                        printUnicodeStr(('Updating complete for',amfNameElement.text))
                        conn.disconnect()
                        next
                    except:
                        print 'Error: Failed to update the auversion record.'
                        # Not clean code - tired
                    conn.disconnect()
                        # print 'Error: Failed to update the auversion record for',amfNameElement.text
    return


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

        if DEBUG:
            pool = Pool(processes=MAX_PROCS)
            pool.map(auvertColl, getColls(amfCollRootPath),1)
            exit(0)

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

updateAuversionColl()    
#exit(auvertColls(AMFCOLLROOTPATH))
