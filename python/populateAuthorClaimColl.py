#!/usr/bin/env python

from authorprofile.common import getMongoDBConn,getMongoDBColl

# AuthorClaimUser objects
def populateMongoDBColl(collName='authorClaimUsers'):

    conn=getMongoDBConn()

    if getMongoDBColl('authorprofile','authorClaimUsers',conn).find_one({'authorClaimUser':{'$exists':True}}):
        print 'Database already populated!'
        exit()

    
    
    conn.disconnect()
    
    exit()

populateMongoDBColl()
