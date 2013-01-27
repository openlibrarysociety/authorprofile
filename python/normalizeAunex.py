#!/usr/bin/python

# This is a utility script which ensures that strings stored in the 'aunex' key for each collection record are normalized

from authorprofile.common import getMongoDBConn,getMongoDBColl
import re
from sys import argv

DB_NAME='authorprofile'
if argv[1]:
    DB_NAME=argv[1]

def getAunexesForColl(coll):
    aunexes=[]
    conn=getMongoDBConn()
    auvertCursor = getMongoDBColl(DB_NAME,coll,conn).find({'aunex':{'$exists':True}})
    if auvertCursor.count():
        print auvertCursor.count(),'records found'

        for record in auvertCursor:
            aunexes.append(record['aunex'])
            return aunexes
    conn.disconnect()
    return aunexes

def normalizeName(normAunex):

    aunex=normAunex
    normAunex=normAunex.lower()

    normAunex=re.sub(r'\'',u'\u2019',normAunex,flags=re.U)
    normAunex=re.sub(r'\W',' ',normAunex,flags=re.U)
    normAunex=re.sub(r'^\s+|\s+$','',normAunex,flags=re.U)
    normAunex=re.sub(r'\s+',' ',normAunex,flags=re.U)

  ## change single quote to curly one
  #  $in=~s/'/\x{2019}/g;
  ## change non-word (word is alphanumeric and _) to space,
  ## avoids dealing with punctuation
  #  $in=~s/\W/ /g;
  ## strip starting and training whitespace
  #  $in=~s/(^\s+|\s+$)//g;
  ## collapse whitespace
  #  $in=~s/\s+/ /g;
  ## minimum 3 useful signs:
  #  if ( $in=~s/(\w)/$1/g < 3 ) {
  #    undef $in;
  #  }
    if len(re.findall(r'(\w)',normAunex,flags=re.U)) < 3:
        return aunex
    #if len(re.match(r'\w',normAunex).groups()) < 3:

        #normAunex=''

    return normAunex

def normAunexesInColl(collName):
    conn=getMongoDBConn()
    coll=getMongoDBColl(DB_NAME,collName,conn)
    auvertCursor = coll.find({'aunex':{'$exists':True}})
    if auvertCursor.count():
        for record in auvertCursor:
            aunex=record['aunex']
            # print 'Updating record for',aunex
            normAunex=normalizeName(aunex)
            coll.update({'aunex':aunex},{'$set':{'aunex':normAunex}})
            # print 'Record for',aunex,'updated with',normAunex
    conn.disconnect()

normAunexesInColl('auversion')

#print normalizeName(getAunexesForColl('auversion').pop())
#print normalizeName('Drusilla\'\' K. Brown')

