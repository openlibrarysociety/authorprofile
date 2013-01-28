from pymongo import Connection

# Constants

AUTHORCLAIM_RECORDS_ROOT_PATH='/home/aupro/ap/amf/3lib/am/'
AMF_NS={'amf':'http://amf.openlib.org'}
ACIS_NS={'acis':'http://acis.openlib.org'}

def getMongoDBConn():

    try:
        conn=Connection()
        return conn
    except:
        #getMongoDBConn()
        print 'Error: Could not connect to the MongoDB server.'

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
