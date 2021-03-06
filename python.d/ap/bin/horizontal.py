#!/usr/bin/python

import sys
import os
import time
import multiprocessing
from multiprocessing import Pool
from pymongo import *
import re

MAX_PROCS=1
cpuCount = multiprocessing.cpu_count()
if cpuCount > 2:
    MAX_PROCS=cpuCount - 1

DEBUG = True
# Too resource-intensive on holda
MAX_PROCS=2

DB_NAME='authorprofile'
COLL_NAME='auversion'
HRZ_DB_NAME=DB_NAME
HRZ_COLL_NAME='horizontal'
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
def getSortedAuthorNames():

    authorNames=[]

    # Firstly, retrieve the aunexes for which the last horizontal integration calculation was not successfully performed.
    # Sort by the time of the last calculation
    conn=getMongoDBConn()
    hrzCursor = getMongoDBColl(HRZ_DB_NAME,HRZ_COLL_NAME,conn).find({'aunex':{'$exists':True},'lastUpdateSuccessful':0},sort=[('timeLastUpdated',1)])
    for hrzRecord in hrzCursor:
        if not (hrzRecord['aunex'] in authorNames):
            authorNames.append(hrzRecord['aunex'])
    conn.disconnect()


    # Retrieve the aunexes for which there is no last horizontal integration data
    # (One must query the 'auversion' collection for the aunexes first, as they would not exist in the 'horizontal' collection).
    # Sort by the time of the last calculation
    conn=getMongoDBConn()
    auvertCursor = getMongoDBColl(DB_NAME,COLL_NAME,conn).find({'aunex':{'$exists':True},'lastUpdateSuccessful':1},sort=[('timeLastUpdated',1)])
    if not auvertCursor.count():
        print 'Fatal Error: No aunexes could be found in',DB_NAME+'.'+COLL_NAME
        exit(1)

    auvertAunexes=[]
    for auvertRecord in auvertCursor:
        auvertAunexes.append(auvertRecord['aunex'])
    conn.disconnect()

    hrzAunexes=[]
    conn=getMongoDBConn()
    hrzCursor=getMongoDBColl(HRZ_DB_NAME,HRZ_COLL_NAME,conn).find({'aunex':{'$exists':1}})
    for hrzRecord in hrzCursor:
            hrzAunexes.append(hrzRecord['aunex'])
    conn.disconnect

    map(auvertAunexes.remove,hrzAunexes)
    hrzAunexes=[]
    authorNames.extend(auvertAunexes)

    # Lastly, retrieve the aunexes for which the last horizontal integration calculation was successfully performed.
    # Sort by the time of the last calculation
    conn=getMongoDBConn()
    hrzCursor = getMongoDBColl(HRZ_DB_NAME,HRZ_COLL_NAME,conn).find({'aunex':{'$exists':True},'lastUpdateSuccessful':1},sort=[('timeLastUpdated',1)])
    for hrzRecord in hrzCursor:
        if not (hrzRecord['aunex'] in authorNames):
            authorNames.append(hrzRecord['aunex'])
    conn.disconnect()

    return authorNames

def updateHorizontalRecord(aunex):

    conn=getMongoDBConn()

    # Horizontal data structure serialized in JSON
    # {aunex: STRING, horizontalNodes: [ STRING1, STRING1, ]}

    try:
        record=getMongoDBColl(HRZ_DB_NAME,HRZ_COLL_NAME,conn).update({'aunex':aunex},{'$set':{'timeLastUpdated':time.time(),'lastUpdateSuccessful':0}},True)
    except:
        # print 'Error: Could not update the horizontal integration record for aunex',aunex,'in the collection',HRZ_COLL_NAME,'in the database',HRZ_DB_NAME
        return 1

    conn.disconnect()
    return record

def storeResults(aunex,results):

    conn=getMongoDBConn()

    # Horizontal data structure serialized in JSON
    # {aunex: STRING, horizontalNodes: [ STRING1, STRING1, ]}

    try:
        record=getMongoDBColl(HRZ_DB_NAME,HRZ_COLL_NAME,conn).update({'aunex':aunex},{'$set': {'horizontalNodes':results,'timeLastUpdated':time.time(),'lastUpdateSuccessful':1}},True)
    except:
        # print 'Error: Could not update the horizontal integration record for aunex',aunex,'in the collection',HRZ_COLL_NAME,'in the database',HRZ_DB_NAME
        return 1

    conn.disconnect()
    return record

def queryDB(queryStr,retrievedAunexes,auvertDBColl):

    # Compile the regex query...
    regexQuery = re.compile(queryStr,re.IGNORECASE)

    # regexQuery = re.compile(('^' + queryStr + '.+'),re.IGNORECASE)
    # ...pass the regex query to the MongoDBMS...
    auvertCursor = auvertDBColl.find({'aunex':regexQuery})
    
    # Records are alphabetically indexed when the MongoDB collection is indexed by aunex
    if auvertCursor.count():

        for auvertRecord in auvertCursor:
            
            # Append the aunex to the list if it's not already stored...
            aunexResult=auvertRecord['aunex']
            if aunexResult not in retrievedAunexes:
                # print 'The following aunex was returned for the query: \''+aunexResult+'\''
                if len(retrievedAunexes) < MAX_RESULTS:
                    # Need to check the auma to determine whether or not these aunexes have been claimed by a registered author
                    retrievedAunexes.append(aunexResult)

    return retrievedAunexes

def craftQueries(aunex,auvertDBColl):

    retrievedAunexes = [aunex]

    # Split by single whitespace.
    initAunexSegments=re.split(' ',aunex)
    
    # First, query for the initial substring - the user could just have likely passed "Smith, John" as "John, Smith"

    # If there are medial substrings...
    if len(initAunexSegments) >= 2:
                
        # First, one would check to ensure that the terminal substring isn't a unique suffix (e.g. "III" or "esq.")
        # (To be implemented)

        # If it wasn't, iterate through the medial substrings

        # John Quincy Adams Smith
        # (Give priority to the "right-most"/"penultimate" name substring)
        # John Quincy Adam Smith
        # John Quincy Ada Smith
        # John Quincy Ad Smith
        # John Quincy A Smith
        # John Quincy Smith
        # (Then, ensure that the penultimate name substring is kept whole for the next series of queries
        # John Quinc Adams Smith
        # John Quin Adams Smith
        # (Then, perform queries in which both are simultaneously reduced)
        # John Quinc Adam Smith
                    
        # Then, a new series of combinations would need to be initiated:
        # John Quincy Adams Smit has been tried.
        # But John Quincy Adam Smit has not.
        # Nor has John Quin Adam Smit.
        # Nor Joh Quin Adam Smit.

        # Can a zipper work for this? (I can't recall...)
        # (Probably not - not iterating through two lists simultaneously...)
        # Unless you nest the zipper within a loop which iterates through each substring, and the zipper zips through multiple
        # # substrings...

        # John Quincy Adams Smith -> John Quincy Adam Smith -> John Quincy Ada Smith
        # Then
        # John Quincy Adams Smith -> John Quinc Adams Smith
        # Then
        # John Quincy Adams Smith -> John Quinc Adam Smith
        # Then
        # John Quincy Adams Smith -> John Quincy Adam Smit -> John Quincy Ada Smit
        # Then
        # John Quincy Adams Smith -> John Quincy Adam Smi -> John Quincy Ada Smi

        # Starting with the last medial / penultimate name substring
        i=len(initAunexSegments) - 2

        medQueryStr=''
        while i > 0:
            
            medAunexSubStr=initAunexSegments[i]
                        
            j = len(medAunexSubStr) - 1
            while j > 0:
                        
                # Trimmed aunex substring
                postMedAunStr=''
                for postMedAunSubStr in initAunexSegments[(i+1):len(initAunexSegments)]:

                    postMedAunStr+=' '+postMedAunSubStr
                preMedAunStr=''
                for preMedAunSubStr in initAunexSegments[0:i]:

                    preMedAunStr+=preMedAunSubStr+' '
                medAunQuery='^'+preMedAunStr+medAunexSubStr[0:j]+'.+'+postMedAunStr
                # print 'Searching for variant \''+re.sub('\.\+','',medAunQuery[1:len(medAunQuery)])+'\'...'
                # Perform the query
                queryDB(medAunQuery,retrievedAunexes,auvertDBColl)
                if len(retrievedAunexes) >= MAX_RESULTS:
                    return retrievedAunexes
                j-=1
            
            # Move to the next substring
            i-=1
                        
        medQueryStr=''

        m=len(initAunexSegments) - 1

        while(m >= 0):

            k=1
            longestElementLength=len(sorted(initAunexSegments,key=lambda u: len(u)).pop())
            while k < longestElementLength:
                for aunexSegment in initAunexSegments:
                    aunexSegment=aunexSegment[0:longestElementLength - k]
                    if medQueryStr:
                        medQueryStr+=' '+aunexSegment
                    else:
                        medQueryStr='^'+aunexSegment

                medQueryStr=re.sub(re.sub('^\^','',re.split(' ',medQueryStr)[m]),re.sub('^\^','',re.split(' ',medQueryStr)[m])+'+.',medQueryStr)

                # print 'Searching for variant \''+re.sub('\.\+','',medQueryStr[1:len(medQueryStr)])+'\'...'
                # regexQuery = re.compile(medQueryStr,re.IGNORECASE)
                queryDB(medQueryStr,retrievedAunexes,auvertDBColl)
                if len(retrievedAunexes) >= MAX_RESULTS:
                    return retrievedAunexes

                medQueryStr=''
                        
                k+=1

            m-=1

        n=0
        # J Q A S+. has already been queried above
        p=1
        aunexInitials='^'
        while p < len(initAunexSegments):
            while n < len(initAunexSegments) - p:
                if len(aunexInitials) > 1:
                    aunexInitials+=' '+initAunexSegments[n][0]
                else:
                    aunexInitials+=initAunexSegments[n][0]
                n+=1
            aunexInitials+='+.'

            # print 'Searching for variant \''+re.sub('\.\+','',aunexInitials[1:len(aunexInitials)])+'\'...'

            queryDB(aunexInitials,retrievedAunexes,auvertDBColl)
            if len(retrievedAunexes) >= MAX_RESULTS:
                return retrievedAunexes

            aunexInitials='^'
            n=0
            p+=1

    # Need to use Levenshtein algorithm to further sort results
    return retrievedAunexes


def getHorizontal(aunex):

    try:
        conn = Connection()
        db = conn[DB_NAME]

    except:
        print 'Error: Could not connect to the database',DB_NAME
        exit(1)

    try:
        auvertDBColl=db[COLL_NAME]
    except:
        print 'Error: Could not find the collection',COLL_NAME,'in the database',DB_NAME
        exit(1)

    queryResults=''

    # auvertCursor = auvertDBColl.find({'aunex':aunex})
    # Long to short: not that many aunexes
    # Short to long: very large number
    # Limiting it, 
    # Metric: Displaying only ...
    # Really want to be showing those aunexes which are most likely to be reached
    # Limit of 1
    # For 'J. Smith'
    # Want to have this grouping ready
    # Show more John Smiths than James Smiths
    # Use vertical integration calculations: local aunexes (depth of 1)
    # Vince Bitone: Bringing Krichel the machine

    # 'John Q. Smith' -> 'John Q Smith'
    normAunex = re.sub('\.','',aunex)
    # 'Smith, John Q.' -> 'Smith John Q'
    normAunex = re.sub(',','',normAunex)

    # As aunexes stored in the database DO contain periods and commas, this will have to be addressed in the formation of the regex query:
    # '^john[\.,]{0,1}\W?smith[\.,]{0,1}$'

    # If this aunex does not exist in the database, then we must not calculate the horizontal integration data (HID) for this aunex
    if auvertDBColl.find({'aunex':aunex}).count():

        # Split by single whitespace.
        initAunexSegments=re.split(' ',aunex)

        queryResults=craftQueries(aunex,auvertDBColl)
        
        # If there are any spaces within the aunex query...
        if len(initAunexSegments) > 1:

            invertAunex = initAunexSegments[len(initAunexSegments) - 1] + re.sub(initAunexSegments[0],'',(re.sub(initAunexSegments[len(initAunexSegments) - 1],'',aunex))) + initAunexSegments[0]

            if auvertDBColl.find({'aunex':invertAunex}).count():
                queryResults+=craftQueries(invertAunex,auvertDBColl)
    else:
        # print "Could not find",aunex,"in the database."
        print "Could not find aunex in the database."

    # Finished
    conn.disconnect()
    if queryResults:
        storeResults(aunex,queryResults)
    return queryResults

#exit(getHorizontal('Daniel Richards'))
#exit(getHorizontal('John Quincy Adams Smith'))

def getHorizontalForSystem():

    if __name__ == '__main__':

        try:
            pool = Pool(processes=MAX_PROCS)
            
        except:
            print 'Fatal Error: Could not instantiate a Pool object'
            exit(1)

        pool.map(getHorizontal,getSortedAuthorNames())
        exit()

        try:
            pool.map(getHorizontal,getSortedAuthorNames())
        except:
            print 'Error: Failed to perform the horizontal integration calculations.'
            exit(1)
            
        print 'Horizontal integration calculations finished at',time.time()
    return 0

exit(getHorizontalForSystem())
