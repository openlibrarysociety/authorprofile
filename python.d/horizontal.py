#!/usr/bin/python

from time import time
from pymongo import Connection
from re import split,compile,IGNORECASE,findall,sub

HRZ_DB_NAME='authorprofile'
HRZ_COLL_NAME='horizontal'
MAX_RESULTS=5
QUERY_LIMIT=100

def decodeUnicodeStr(string):
    for encChar in findall(r'\\x.{2}',string):
        string=sub('\\'+encChar,('00' + sub(r'\\x','',encChar).upper()),string)
        for utf8Char in findall(r'\\u.{4}',string):
            string=sub('\\'+utf8Char,(sub(r'\\u','',utf8Char).upper()),string)
    return string

def printUnicodeStr(string):
    try:
        print string
    except:
        try:
            print decodeUnicodeStr(string)
        except:
            print 'Error: Could not print string to STDOUT'
    return

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
        return None

    try:
        coll=db[collName]
    except:
        print 'Error: Could not find the collection',collName,'in the database',dbName
        return None

    return coll

def getHrzRecordsRegex(regexStr):

    conn=getMongoDBConn()

    regex=compile(regexStr,IGNORECASE)

    try:
        records=getMongoDBColl('authorprofile','auversion',conn).find({'aunex':regex},limit=QUERY_LIMIT,sort=[('timeaunex',1)])

    except:
        printUnicodeStr('Error retrieving records for query '+regex)

    conn.disconnect()
    return records

def getHrzRecord(aunex):
    conn=getMongoDBConn()
    try:
        record=getMongoDBColl('authorprofile','horizontal',conn).find_one({'aunex':aunex})
    except:
        printUnicodeStr('Error retrieving horizontal record for '+aunex)

    conn.disconnect()
    return record

def updateHrzRecord(aunex,hrzAunex):

    record=getHrzRecord(aunex)
    if not hrzAunex in record['horizontalNodes']:
        conn=getMongoDBConn()
        try:
            getMongoDBColl(HRZ_DB_NAME,HRZ_COLL_NAME,conn).update({'aunex':aunex},
                                                                  {'$set':
                                                                       {'timeLastUpdated':time(),
                                                                        'lastUpdateSuccessful':0
                                                                        },
                                                                   '$push':
                                                                       {'horizontalNodes':hrzAunex,
                                                                        }
                                                                   },
                                                                  True)
            printUnicodeStr('Successfully updated horizontal record for '+aunex+' at '+str(time()))
        except:
            printUnicodeStr('Error updating horizontal record for '+aunex)
        conn.disconnect()
    #else:print'already stored'
    return hrzAunex

def appendAunexes(aunex,hrzResults,queryStr):

    records=getHrzRecordsRegex(queryStr)
    for hrzRecord in records:
        if(
            not hrzRecord['aunex'] in hrzResults 
            and hrzRecord['aunex']!=aunex 
            and len(hrzResults) < MAX_RESULTS):

            printUnicodeStr('Found '+hrzRecord['aunex'])
            hrzResults.append(updateHrzRecord(aunex,hrzRecord['aunex']))

#            hrzResults.append(hrzRecord['aunex'])
#            updateHrzRecord(aunex,hrzRecord['aunex'])

    return hrzResults

def getHorizontal(aunex):
    nameSubstrings=split(' ',aunex)
    hrzAunexes=[]

    i=len(nameSubstrings)

    while i >= 2:
        nameSubstringPair=nameSubstrings[i-2:i]
        prevNameSubstrings=''
        m=i-2
        for prevNameSubstring in nameSubstrings[0:m]:
            prevNameSubstrings+=prevNameSubstring+' '
        k=len(nameSubstringPair[-1])
        while k > 0:
            j=len(nameSubstringPair[0])
            while j > 0:
                printUnicodeStr('Searching with '+prevNameSubstrings+nameSubstringPair[0][0:j]+' '+nameSubstringPair[-1][0:k]+'...')
                if len(appendAunexes(aunex,hrzAunexes,
                                     '^'+prevNameSubstrings+nameSubstringPair[0][0:j]+'+ '+nameSubstringPair[-1][0:k]+'+')) >= MAX_RESULTS:
                    #if len(hrzAunexes) > MAX_RESULTS:
                    return hrzAunexes
                j-=1
            k-=1
        i-=1

    n=len(aunex)
    while n > 0:
        printUnicodeStr('Searching with '+aunex[0:n])
        if len(appendAunexes(aunex,hrzAunexes,'^'+aunex[0:n]+'+')) >= MAX_RESULTS:
            #if len(hrzAunexes) > MAX_RESULTS:
            return hrzAunexes
        n-=1

#sorted("This is a test string from Andrew".split(), key=str.lower)
#print sorted(getHorizontal('Thomas Krichel'), key=unicode.lower)
#print 'finished'
