#!/usr/bin/python

import re
from os.path import join
from os import listdir
from authorprofile.common import getMongoDBColl,getMongoDBConn

conn=getMongoDBConn()
records=getMongoDBColl('authorprofile','auversion',conn).find({'amfCollection':{'$exists':True},'lastUpdateSuccessful':False})
numberOfRecords=records.count()
if numberOfRecords:
    print 'The auversion process has not finished for',numberOfRecords,'files:'
    for record in records:
        print record['filePath']
conn.disconnect()

conn=getMongoDBConn()
records=getMongoDBColl('authorprofile','auversion',conn).find({'aunex':{'$exists':True},'lastUpdateSuccessful':False})
if records.count():
    print 'Auversion insertion/updates have not finished for the following author-namestrings/aunexes:'
    for record in records.sort('timeLastUpdated'):
        print record['aunex']
conn.disconnect()

for pid in [pid for pid in listdir('/proc') if pid.isdigit()]:
#print open(os.path.join('/proc', pid, 'cmdline'), 'rb').read()
    cmdLineInvocation=open(join('/proc', pid, 'cmdline'), 'rb').read()
    if 'vertical.pl' in cmdLineInvocation:
        print 'Vertical integration calculations are currently being performed for:',re.search('p[a-zA-Z]{2}\d+',cmdLineInvocation).group(0)

conn=getMongoDBConn()
records=getMongoDBColl('authorprofile','noma',conn).find({'author':{'$exists':True},'began_calculation':{'$exists':False}})
if records.count():
    print 'Vertical integration calculations have not been performed for the following authors:'
    for record in records.sort('last_change_date'):
        print record['author']
conn.disconnect()

conn=getMongoDBConn()
records=getMongoDBColl('authorprofile','noma',conn).find({'author':{'$exists':True}})
#if records.count():
numberOfRecords=records.count()
incompleteVerticalAuthors=numberOfRecords
if numberOfRecords:
    print 'Vertical integration calculations have not finished for',numberOfRecords,'authors:'
    for record in records.where('this.began_calculation > this.ended_calculation').sort('began_calculation'):
        print record['author']
conn.disconnect()

conn=getMongoDBConn()
records=getMongoDBColl('authorprofile','noma',conn).find({'author':{'$exists':True}})
#if records.count():
numberOfRecords=records.count()
completeVerticalAuthors=numberOfRecords
if numberOfRecords:
    print 'Vertical integration calculations have finished for',numberOfRecords,'authors:'
    #print 'Vertical integration calculations have finished for the following authors:'
    for record in records.where('this.began_calculation < this.ended_calculation').sort('began_calculation'):
        print record['author']
conn.disconnect()

#totalVerticalAuthors=incompleteVerticalAuthors+completeVerticalAuthors

print str(100.00/((incompleteVerticalAuthors+completeVerticalAuthors)/incompleteVerticalAuthors))+'% of authors have consistent vertical integration data'
