from pymongo import Connection

from string import punctuation
from time import strptime,tzset,mktime
from os import walk,path,environ,stat
from lxml import etree
from re import sub,split,findall,escape
import re

# Python does not permit me to designate a single .py file for a single class definition
# I would much prefer this method
# I could implement authorprofile.classname.ClassName, but this doesn't seem to be the scheme that most Python developers use

# Constants

AMF_AUVERSION_ROOT_PATH='/home/aupro/ap/amf/auverted/'
AUTHORCLAIM_RECORDS_ROOT_PATH='/home/aupro/ap/amf/3lib/am/'
AMF_NS={'amf':'http://amf.openlib.org'}
ACIS_NS={'acis':'http://acis.openlib.org'}

MONGODB_DB='authorprofile'
AUTHORCLAIM_USERS_MONGODB_COLL='authorclaimusers'
AUVERSION_MONGODB_COLL='auversion'
AUTHORS_MONGODB_COLL='authornodes'

# Functions

def normalizeAunex(authorNameStr,auversionFile=False):


    if auversionFile:
        # Place the aunex in the lower case and replace all spaces with underscores:
        authorNameStr = sub('[\ \-]','_',authorNameStr.lower())
        # Remove commas
        authorNameStr = sub(',','',authorNameStr)
        # Remove periods
        authorNameStr = sub('\.','',authorNameStr)
        # Remove initial underscores
        authorNameStr = sub('^_','',authorNameStr)
        # Remove all brackets
        authorNameStr = sub('\[','',sub('\]','',authorNameStr))
    else:
        authorNameStr = sub('['+escape(punctuation)+']','',
                            sub('\-',' ',authorNameStr.lower()))

        return authorNameStr

    authorNameStr = authorNameStr.encode('ascii', 'backslashreplace')

    # For Non-ASCII character sets and Unicode...
    for encChar in findall(r'\\x.{2}',authorNameStr):
        authorNameStr = sub('\\' + encChar,('00' + sub(r'\\x','',encChar).upper()),authorNameStr)

    for utf8Char in findall(r'\\u.{4}',authorNameStr):
        authorNameStr = sub('\\' + utf8Char,(sub(r'\\u','',utf8Char).upper()),authorNameStr)

    return authorNameStr

def getFilePathForAuthorFromDB(authorName):

    conn=getMongoDBConn()
    record=getMongoDBColl(AUVERSION_MONGODB_COLL,conn).find_one({'aunex':re.compile('/'+normalizeAunex(authorName)+'/')},{'filePath':True})
    amfFilePath=''
    if record:
        amfFilePath=record['filePath']
    conn.disconnect

    return amfFilePath

# Imported from auvertd.py

def getFilePathForAunex(aunex):

    # Try the MongoDB first.

    relAuvFilePath = ''

    relAuvFilePath=getFilePathForAuthorFromDB(aunex)
    if relAuvFilePath:return AMF_AUVERSION_ROOT_PATH+relAuvFilePath

    print 'Could not find the auversion file path in the MongoDB for',aunex

    # Only resort to the algorithm if it doesn't exist.


    normAunex=normalizeAunex(aunex,True)

    charCount = 1
    charGroupCount = 0
    maxGroupChar = 1
    for aunChar in normAunex:
        
        relAuvFilePath += aunChar
        pathWOSlashes = split('/',relAuvFilePath)

        charFromSlash = len(pathWOSlashes[len(pathWOSlashes) - 1])
        totalSlashes = len(findall('/',relAuvFilePath))

        if charFromSlash >= charCount:
            relAuvFilePath += '/'
            charGroupCount += 1

            if charGroupCount >= maxGroupChar:
                maxGroupChar += 1
                charGroupCount = 0
                charCount = maxGroupChar

    # Inefficient
    auversionFilePath = AMF_AUVERSION_ROOT_PATH+sub('/$','',relAuvFilePath)+'.amf.xml'

    # Verify that the file exists.
    if path.isfile(auversionFilePath):return auversionFilePath

    print 'File path',auversionFilePath,'doesn\'t exist'

    return False

def getMongoDBConn():

    try:
        conn=Connection()
        return conn
    except:
        print 'Error: Could not connect to the MongoDB server.'

def getMongoDBColl(collName,conn,dbName=MONGODB_DB):

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

def getAMFFilePathForACISID(acisID):

    return AUTHORCLAIM_RECORDS_ROOT_PATH+sub('(.)','\\1/',sub('\d*$','',acisID[1:len(acisID)]))+acisID+'.amf.xml'

def getACISIDForAMFDoc(amfDoc):
    try:
        return amfDoc.xpath('//acis:shortid/text()',namespaces=ACIS_NS).pop(0)

    except:
        pass

def getACISNameVarForAMFDoc(amfDoc):

    try:
        return amfDoc.xpath('//acis:variation/text()',namespaces=ACIS_NS)

    except:
        pass

def updateAuthorClaimUsers(collName=AUTHORCLAIM_USERS_MONGODB_COLL):

    for rootPath,dirs,files in walk(AUTHORCLAIM_RECORDS_ROOT_PATH):
        for fileName in files:
            amfFilePath=path.join(rootPath,fileName)
            print 'Creating object for',amfFilePath
            try:
                AuthorClaimUser(amfFilePath,noDBUpdate=False)
            except:
                print 'Could instantiate AuthorClaimUser for',amfFilePath
                raise
    exit()
    pass


# Classes

class AuthorClaimUser:

    def getACISLastChangeDate(self):
        
        # db.authorclaimusers.find({},{timeLastUpdated:true})
        
        # Non-existent data in the AuthorClaim user profile document element <acis:last-change-date> (!)
        #     last_change_date=amfDoc.xpath('//acis:last-change-date/text()',namespaces=ACIS_NS).pop(0)
        # IndexError: pop from empty list
        
        # Conversion from the formatted string
        try:
            last_change_date=self.amfDoc.xpath('//acis:last-change-date/text()',namespaces=ACIS_NS).pop(0)
            
        except:
            print 'Warning: No value found for <acis:last-change-date> in AuthorClaim record (using mtime of file)'
            return stat(self.amfFilePath).st_mtime
        
        # Inconsistent data in the AuthorClaim user profile document element <acis:last-change-date>
        # ValueError: time data '1320696920' does not match format '%Y-%m-%d %H:%M:%S'
        
        tz=sub('([\+-]\d+$)','UTC\\1',
               split(' ',last_change_date).pop())
        environ['TZ']=tz
        tzset()
        try:
            return mktime(strptime(sub('( [\+-]\d+$)','',last_change_date),'%Y-%m-%d %H:%M:%S'))
        except:
            print 'Warning: Inconsistency in <acis:last-change-date> found:',last_change_date
            return last_change_date


    def updateMongoDBColl(self,collName=AUTHORCLAIM_USERS_MONGODB_COLL):

        # Each time an AuthorClaimUser object is instantiated, the MongoDB record COULD updated with the most relevant information
        # This could introduce some significant problems if objects are instantiated irresponsibly

        # As of this moment, AuthorClaim objects are singletons - for each network exploration script instance executed, one can only be certain that a single node is an AuthorClaim user (the root of the tree)

        # Other nodes are rejected outright (as we're interested in discovering the shortest paths from unidentified authors to AuthorClaim users)
        # IF THIS WERE TO CHANGE, YOU CANNOT UPDATE THE MONGODB WITH EVERY INSTANTIATION!

        #print self.toJSON()
        #exit()

        conn=getMongoDBConn()
        try:
            return getMongoDBColl(collName,conn).update({'acisID':self.acisID},{'$set':self.toJSON()},True,safe=True)
        except:
            print 'Could not update'
            raise
        conn.disconnect()

    def toJSON(self):

        return {'class':AuthorClaimUser.__name__,'acisID':self.acisID,'amfFilePath':self.amfFilePath,'nameVariations':self.nameVariations,'isauthorofTexts':self.isauthorofTexts,'timeLastUpdated':self.timeLastUpdated}

    def getClaimedTexts(self):

        try:
            return self.amfDoc.xpath('//amf:isauthorof/amf:text/@ref',namespaces=AMF_NS)

        except:
            pass


    # Can instantiate either by directly parsing the AuthorClaim user record or with the ACIS ID.
    def __init__(self,amfFilePath=None,acisID=None,noDBUpdate=True):

        if not amfFilePath and acisID:
            amfFilePath=getAMFFilePathForACISID(acisID)

        try:
            self.amfDoc=etree.parse(amfFilePath)

        except:
            print 'Could not parse the AuthorClaim XML file',amfFilePath
            raise

        self.amfFilePath=amfFilePath

        # Get the name variations
        self.nameVariations=getACISNameVarForAMFDoc(self.amfDoc)

        if not acisID:
            acisID=getACISIDForAMFDoc(self.amfDoc)

        self.acisID=acisID

        self.isauthorofTexts=self.getClaimedTexts()

        self.timeLastUpdated=self.getACISLastChangeDate()

        # Get the last_change_date property

        # See my warning in the declaration for updateMongoDBColl()
        if not noDBUpdate:
            self.updateMongoDBColl()

    def __repr__(self):

        return str(self.toJSON())
