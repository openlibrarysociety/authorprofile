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

DEBUG = False
AMFXMLNS = {'amf':'http://amf.openlib.org'}

def getAuvTextXML(amfText,aunex):

    for author in amfText.findall('amf:hasauthor',namespaces=AMFXMLNS):
        if author.getchildren()[0].findtext('amf:name',namespaces=AMFXMLNS) != aunex:
            amfText.remove(author)

    return amfText

def getAuvComment(collFilePath,aunexID):

    relFilePath = re.sub('^/','',re.sub('.amf.xml$','',re.sub(amfCollRootPath,'',collFilePath)))
    return etree.Comment(relFilePath + ' ' + str(aunexID) + ' ' + str(time.time())) # Append the comment to the AMF file

def getFilePathForAunex(aunex):


    # print aunex
    #for aunChar in aunex:
        #print aunChar
    #if re.findall('x.{2}',aunex):
        #print aunex
        #exit()

    relAuvFilePath = ''

    # Place the aunex in the lower case and replace all spaces with underscores:
    normAunex = re.sub(' ','_',aunex.lower())
    # Remove commas
    normAunex = re.sub(',','',normAunex)
    # Remove periods
    normAunex = re.sub('\.','',normAunex)
    # Remove initial underscores
    normAunex = re.sub('^_','',normAunex)
    # Remove all brackets
    normAunex = re.sub('\[','',re.sub('\]','',normAunex))

    charCount = 1
    charGroupCount = 0
    maxGroupChar = 1
    for aunChar in normAunex:
        
        relAuvFilePath += aunChar
        pathWOSlashes = re.split('/',relAuvFilePath)

        charFromSlash = len(pathWOSlashes[len(pathWOSlashes) - 1])
        totalSlashes = len(re.findall('/',relAuvFilePath))

        if charFromSlash >= charCount:
            relAuvFilePath += '/'
            charGroupCount += 1

            if charGroupCount >= maxGroupChar:
                maxGroupChar += 1
                charGroupCount = 0
                charCount = maxGroupChar

    # Inefficient
    relAuvFilePath = re.sub('/$','',relAuvFilePath)

    relAuvFilePath = relAuvFilePath.encode('ascii', 'backslashreplace')

    # For Non-ASCII character sets and Unicode...
    for encChar in re.findall(r'\\x.{2}',relAuvFilePath):
        relAuvFilePath = re.sub('\\' + encChar,('00' + re.sub(r'\\x','',encChar).upper()),relAuvFilePath)

    for utf8Char in re.findall(r'\\u.{4}',relAuvFilePath):
        relAuvFilePath = re.sub('\\' + utf8Char,(re.sub(r'\\u','',utf8Char).upper()),relAuvFilePath)

    # For UTF-8
    # for uChar in re.findall(r'\\x.{2}',relAuvFilePath):
        # relAuvFilePath = re.sub(
            # Search for the character point...
            # re.sub(r'\\x','',uChar),
            # ...replace it with hex values formatted with A-F in the upper case...
            # str(00) + re.sub(r'\\x','',uChar).upper(),
            # ...and remove the '\x' from the original file path.
            # re.sub(r'\\x','',relAuvFilePath))

    # For UTF-16
    # for uChar in re.findall(r'\\u.{4}',relAuvFilePath):
        # relAuvFilePath = re.sub(
            # Search for the character point...
            # re.sub(r'\\u','',uChar),
            # ...replace it with hex values formatted with A-F in the upper case...
            # re.sub(r'\\u','',uChar).upper(),
            # ...and remove the '\x' from the original file path.
            # re.sub(r'\\u','',relAuvFilePath))

    return relAuvFilePath

def getAunexIndexForText(amfText):
    aunexID = {}
    aunexIndex = 1

    for authorElem in amfText.findall('amf:hasauthor',namespaces=AMFXMLNS):
        # Don't exclusively index <person>'s
        aunex = ''
        try:
            aunex = authorElem.getchildren()[0].find('amf:name',namespaces=AMFXMLNS).text
        except:
            print 'could not retrieve aunex'
            continue


        aunexID[aunex] = aunexIndex
        aunexIndex += 1

    return aunexID

def getCollFiles(collPath): # Get a list of all of the files contained in a collection

    # 09/24/11
    # I'm either performing a regex operation twice, or checking EXCLUDEPATHS twice

    collFiles=[]

    for collChild in os.listdir(collPath): # For each child directory/file/node within a child dir/file/node...
        #collChild = collPath + collChild # ...first transform the relative path into the absolute path...
        if os.path.isdir(collPath + collChild):
            collFiles.append(collChild) # ...append the file path to the array.

    return collFiles



    if collPath in EXCLUDEPATHS or (collPath + '/') in EXCLUDEPATHS:
        return []

    if not re.search('/$',collPath): # Fix the trailing slash
        collPath+='/'

        

    if not os.path.isdir(collPath):
        print 'Warning: A file path',collPath,'was passed for a directory path.'
        # 09/24/11 Minor adjustment necessary
        # return [collPath]
        return []

    try:
        os.listdir(collPath)
    except:
        print 'Warning: Directory path',collPath,'could not be opened.' # Should be throwing an exception
        # 09/09/11: This is creating the problem.  The value 1 is being passed as a parameter to the auvertColl function.  Should have the auvertColl return a value of 1 immediately if it is not passed a valid file path.
        # return collFiles
        # 09/15/11: For the sake of convenience, I'm simply returning an array with a single element
        # This isn't the proper way to implement this, but I'm short on time
        # return collFiles.append(collPath) # This returns None?
        # 09/24/11 Minor adjustment necessary
        # return [collPath]
        return [] # Treat the problematic path like a file

    collFiles=[]

    for collChild in os.listdir(collPath): # For each child directory/file/node within a child dir/file/node...
        collChild = collPath + collChild # ...first transform the relative path into the absolute path...
        if not os.path.isdir(collChild) and re.search('\.amf\.xml$',collChild): # ...and if it's not a subdirectory...
            collFiles.append(collChild) # ...append the file path to the array.
        elif os.path.isdir(collChild): # ...and if it is a subdirectory...
            for collSubDirChild in getCollFiles(collChild): # ...recurse... (Ignoring the maximum recursion limit: sys.getrecursionlimit())
                collFiles.append(collSubDirChild) # ...and append all results to the array.
    return collFiles

def auvertColl(collFile): # Auversion function

    amfCollRootPath = AMFCOLLROOTPATH

    # 09/09/11
    # To be done: Error message generation should be abstracted through deriving a class from Exception and throwing such an exception.

    if not os.path.isfile(collFile):
        print 'Error: Invalid file path',collFile,'passed to function auvertColl'
        return 1

    try:
        conn = Connection()
        # db = conn['asyncAuvert']
        db = conn['auversion']

    except:
        # print 'Error: Could not connect to the MongoDB database \'asyncAuvert\' for ',collFile
        print 'Error: Could not connect to the MongoDB database \'auversion\' for ',collFile
        return 1

    # Retrieve the database collection name
    # collName = re.split('/',re.sub('^/','',re.sub('/$','',re.match('^.*/',re.split(amfCollRootPath,collFile)[1]).group(0))))[0]
    collName = 'syncAuvert'

    # if not collName:
        # print 'Error: Could not generate the MongoDB collection name for',collFile
        #return 1

    try:
        auvertDBColl=db[collName]
        
    except:
        # print 'Error: Could not open the MongoDB collection \'',collName,'\' in the database \'asyncAuvert\''
        print 'Error: Could not open the MongoDB collection \'',collName,'\' in the database \'auversion\''        
        return 1

    mongoSema.acquire()
    amfTree=None

    try: # Open the AMF record file...
        collFH=open(collFile) # Explicitly opened and closed in order to avoid any problems which may arise with open file handles and concurrency
        amfTree=etree.parse(collFH)
        collFH.close()
    except:
        print 'Error: Could not parse',collFile
        return 1

    amfRoot=None

    try:
        amfRoot = amfTree.getroot()
    except:
        print 'Error: Could not retrieve the root element for ',collFile
        return 1

    for amfText in amfRoot.findall('amf:text',namespaces=AMFXMLNS): # Retrieve all <text>'s

        amfTextID = amfText.get('id')
        authors = []
        amfTextAunexID = getAunexIndexForText(amfText)

        print 'Found record',amfTextID

        try:
            authors=amfText.findall('amf:hasauthor',namespaces=AMFXMLNS) # Retrieve the authors for amfText
        except:
            print 'Error: Could not find any <author>\'s for <text> in',collFile
            continue

        # print etree.tostring(amfText)

        for amfAuthor in authors:

            aunex=None

            try:
                # Include elements alternative to <person>
                aunex=amfAuthor.getchildren()[0].findtext('amf:name',namespaces=AMFXMLNS) # Retrieve the aunex

            except:
                print 'Error: Could not find any <name>\'s for <person>\'s in',collFile
                continue

            if not aunex:
                print 'Error: Returned an empty aunex for',amfTextID
                continue

            #print 'Found aunex',aunex

            xmlString = etree.tostring(amfText,pretty_print=False,encoding=unicode,with_tail=False)

            # print 'Found XML record',xmlString

            if not re.search('/$',amfCollRootPath):
                amfCollRootPath+='/'

            auvertFilePath = amfAuvOutPath + getFilePathForAunex(aunex) + '.amf.xml'

            if os.path.isfile(auvertFilePath) and os.stat(auvertFilePath)[6]: # If an auversion record file already exists and isn't empty...
                
                try: #...open the record and parse the XML tree...
                    auvertFH=open(auvertFilePath) # Explicitly opened and closed in order to avoid any problems which may arise with open file handles and concurrency
                    auvertFileTree=etree.parse(auvertFH)
                    auvertFH.close()
                except:
                    print 'Error: Could not parse',auvertFilePath
                    continue

                if auvertFileTree.find(('amf:text[@id=\'' + amfTextID + '\']'),namespaces=AMFXMLNS) is None: # Retrieve the <text> bearing the id from the file
                    #auvertFH=open(auvertFilePath,'w') # Explicitly opened and closed in order to avoid any problems which may arise with open file handles and concurrency

                    # auvertFileTree.getroot().append(etree.Element(xmlString)) # Could also use etree.SubElement(auvertFileTree.getroot(), xmlString)
                    #amfTextString = etree.tostring(auvertFileTree.getroot(),
                                                   #pretty_print=False,encoding=unicode,with_tail=False)
                    #print amfTextString
                    #exit()

                    try: # To be implemented: use 'with' keyword
                        # Write the auversion file before storing the XML into the database
                        # The writing of the auversion file received priority, as the database records may become corrupted
                        auvertFH=open(auvertFilePath,'w') # Explicitly opened and closed in order to avoid any problems which may arise with open file handles and concurrency
#                        auvertFileTree.getroot().append(etree.fromstring(xmlString)) # Could also use etree.SubElement(auvertFileTree.getroot(), xmlString)
                    except:
                        print 'Error: Could not open auversion record file',auvertFilePath

                    amfRoot = auvertFileTree.getroot()
                    
                    #try:

                     #   amfString = etree.tostring(amfRoot,
                      #                                     pretty_print=False,encoding=unicode,with_tail=False)
                    #except:
                     #   print 'Could not parse the auversion record for',aunex
                      #  continue

                    # Preferable, but unnecessary for now
                    # xmlHeaderString = '<?xml version="1.0"?>'
                    # amfXMLRootString = '<amf xmlns="http://amf.openlib.org" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://amf.openlib.org http://amf.openlib.org/2001/amf.xsd">'
                    # amfXMLString = xmlHeaderString + amfXMLRootString + amfTextString + '</amf>'

                    # This was unnecessary: We're updating
                    # amfXMLString = '<?xml version="1.0"?><amf xmlns="http://amf.openlib.org" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://amf.openlib.org http://amf.openlib.org/2001/amf.xsd">' + amfTextString + xmlString + '</amf>'

                    try:
                        # auvAMFText = getAuvTextXML(etree.fromstring(xmlString),aunex)
                        auvAMFText = etree.fromstring(xmlString)

                    except:
                        print 'Error: Could not parse auverted XML block.'
                        exit()

                    #try:
                        #xmlString = etree.tostring(auvAMFText,
                         #                          pretty_print=False,encoding=unicode,with_tail=False)
                    #except:
                        #print 'could not convert auverted XML text block to string'
                        #exit()

                    #print amfString
                    #print xmlString
                    #exit()
                        
                    auvAMFText.append(getAuvComment(collFile,amfTextAunexID[aunex])) # Append the comment to the AMF file                
                    amfRoot.append(auvAMFText)
                    # print etree.tostring(amfRoot)
                    #exit()

                    #amfXMLRoot = etree.fromstring(amfXMLString)

                    # Prune all <hasauthor> elements which contain <person><name>AUNEX</name></person> where AUNEX != aunex

                    #amfXMLRoot.append(getAuvComment(collFile,amfTextAunexID[aunex])) # Append the comment to the AMF file                
                    # amfXMLRoot.append(etree.Comment(collName + ' ' + str(amfTextAunexID[aunex]) + ' ' + str(time.time()))) # Append the comment to the AMF file
                    #amfXMLRootString = etree.tostring(amfXMLRoot,pretty_print=False,encoding=unicode,with_tail=False)
                    amfRootString = etree.tostring(amfRoot,encoding=unicode,pretty_print=False,with_tail=False)
                    #print amfXMLRootString
                    #exit()

                    # print amfRootString.encode('ascii', 'backslashreplace')
                    # DISABLED FOR DEBUGGING
                    #try:
                    auvertFH.write(amfRootString.encode('utf-8'))
                    # auvertFileTree=etree.parse(auvertFH)
                    auvertFH.close()
                    # DISABLED FOR DEBUGGING
                    #except:
                       # print 'Error: Could not append to file',auvertFilePath
                        #exit()

                    #print 'Successfully updated auversion record file for',aunex,'with AMF record for',amfTextID
                    # exit()

                else: # If it has been stored in the auversion record...

                    # This should be performed BEFORE searching for the <text> in the auversion record...
                    #print 'Record for',amfTextID,'already stored in the auversion record file for',aunex

                    try:
                        # auvAMFText = getAuvTextXML(etree.fromstring(xmlString),aunex)
                        auvAMFText = etree.fromstring(xmlString)

                    except:
                        print 'Error: Could not parse auverted XML block.'
                        exit()

                    auvAMFText.append(getAuvComment(collFile,amfTextAunexID[aunex])) # Append the comment to the AMF file                
                    amfRoot.append(auvAMFText)

                    amfRootString = etree.tostring(amfRoot,encoding=unicode,pretty_print=False,with_tail=False)

            else: # Write a new auversion file
                auvertDirPath = re.split('/[0-9a-zA-Z_]*$',re.split('.amf.xml$',auvertFilePath)[0])[0]
                if not os.path.exists(auvertDirPath):
                    # print re.split(amfCollRootPath,auvertFilePath)
                    # print re.split('.amf.xml$',auvertFilePath)
                    # print re.split('/[0-9a-zA-Z_]*$',re.split('.amf.xml$',auvertFilePath)[0])[0]
                    # exit()
                    os.makedirs(auvertDirPath)
                auvertFH=open(auvertFilePath,'w') # Explicitly opened and closed in order to avoid any problems which may arise with open file handles and concurrency

                try:
                    # auvAMFText = getAuvTextXML(etree.fromstring(xmlString),aunex)
                    auvAMFText = etree.fromstring(xmlString)

                except:
                    print 'Error: Could not parse auverted XML block.'
                    exit()

                # Could not remove the namespace declaration within <text>: this seems to be a feature in lxml
                auvAMFTextString = etree.tostring(auvAMFText,
                                                  pretty_print=False,encoding=unicode,with_tail=False)

                # This requires less parsing
                amfXMLString = '<?xml version="1.0"?><amf xmlns="http://amf.openlib.org" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://amf.openlib.org http://amf.openlib.org/2001/amf.xsd">' + auvAMFTextString + '</amf>'

                amfXMLRoot = etree.fromstring(amfXMLString)

                amfXMLRoot.append(getAuvComment(collFile,amfTextAunexID[aunex])) # Append the comment to the AMF file                
                etree.cleanup_namespaces(amfXMLRoot)
                # etree.SubElement(amfXMLRoot,getAuvComment(collFile,amfTextAunexID[aunex]))
                # amfXMLRoot.append(etree.Comment(collName + ' ' + str(amfTextAunexID[aunex]) + ' ' + str(time.time()))) # Append the comment to the AMF file
                
                amfRootString = etree.tostring(amfXMLRoot,
                                                  pretty_print=False,encoding=unicode,with_tail=False)

                auvertFH.write(amfRootString.encode('utf-8'))
                # auvertFileTree=etree.parse(auvertFH)
                auvertFH.close()
                #print 'Successfully created auversion record file for',aunex,'with AMF record for',amfTextID

            # Search the MongoDB for Auversion record for an aunex
            auvertCursor = auvertDBColl.find({'aunex':aunex})

                # print 'Could not query the MongoDB database \'asyncAuvert\' for aunex',aunex
                #print 'Error: Could not query the MongoDB database \'auversion\' for aunex',aunex

            # print 'Initial aunex query results:',auvertCursor.count()

            xmlStored = False # Inefficient
            # TEMPORARY
            xmlString = amfRootString

            if auvertCursor.count(): #???
                if auvertCursor.count() > 1:
                    #print 'Error: Auversion data for',aunex,'corrupted: multiple records for one aunex found.'
                    continue

                try:
                    # Deprecated, not storing XML as an array
                    # auvertXMLRecords = auvertCursor[0]['xml']
                    auvertXMLRecord = auvertCursor[0]['xml']
                except:
                    #print 'Error: Could not retrieve the XML strings in the auversion record for',aunex
                    continue

                # Check each XML string within the auversion record
                # Deprecated
                # for storedXMLString in auvertXMLRecords: # Inefficient
                    # if xmlString == storedXMLString:
                        # xmlStored = True
                        # print 'Record for',amfTextID,'already stored for',aunex
                        # break

                # Parse stored XML...
                storedAMF = etree.fromstring(auvertCursor[0]['xml'])
                if storedAMF.find(('amf:text[@id=\'' + amfTextID + '\']'),namespaces=AMFXMLNS) is not None: # ...and search for the <text>
                    xmlStored = True
                    #print 'Record for',amfTextID,'already stored in MongoDB for',aunex
                    break
                
                # if xmlString == auvertCursor[0]['xml']:
                    # xmlStored = True
                    # print 'Record for',amfTextID,'already stored for',aunex
                    # break

            if not xmlStored: # If the XML hasn't been stored in the database, store it here
                updateTime = time.time()

                try:
                    auvertDBColl.update(
                        {'aunex':aunex},
                        # Deprecated, not adding to an array
                        # {'$addToSet':
                             # {'xml':xmlString},
                        # db.test.update({"x": "y"}, {"$set": {"a": "c"}})
                        # myColl.update( { _id: X }, { _id: X, name: "Joe", age: 20 }, true );
                        {'$set':
                             {'xml':xmlString,
                              'updated':updateTime}},
                        upsert=True)

                except:
                    # print 'Could not update the auversion record for',aunex,'in the collection',collName,'in the database \'asyncAuvert\''
                    #print 'Could not update the auversion record for',aunex,'in the collection',collName,'in the database \'auversion\''
                    continue
            
                #print 'Record for',amfTextID,'successfully inserted into the auversion record for',aunex,'at',updateTime

    conn.disconnect()
    mongoSema.release()
    return 0

def auvertColls(collPath):

#    if not re.search('/$',collPath):
#        collPath+='/'

    if not os.path.isdir(collPath):
        print "Error:",collPath,"is not a valid collection directory path."
        return 1

    if __name__ == '__main__': # Auvert the files
        
        # There is a formula for designating the proper number of processes to generate given the number of cores available
        # This should be properly implemented, but I simply wanted to get the script working
        # An alternative approach might be to use Jython and utilize Java's own Executor framework (which, I believe, performs these calculations for us)...
        try:
            cpuCount = multiprocessing.cpu_count()
            if cpuCount > 1:
                pool = Pool(processes = (cpuCount - 1))
            else:
                pool = Pool(processes=1)
        except:
            print 'Error: Could not instantiate a Pool object'
            return 1

        # Debug
        if DEBUG:
            pool.map(auvertColl, getCollFiles(collPath))
        # print collPath
        # print '/3lib/RePEc/aaabookis.amf.xml'
        # auvertColl(collPath + '/RePEc/aaabookis.amf.xml',amfCollRootPath)
        # exit()
        else:

            try:
                pool.map(auvertColl, getCollFiles(collPath))
            except:
                print 'Error: Could not asynchronously \'auvert\' the files in the collections stored for',collPath
                return 1
            
        print 'Synchronous \'auversion\' finished at',time.time()

# Note: This should be a percentage of the maximum connections returned by db.serverStatus()
# I'm unsure as to how exactly we plan on sharing access between the different scripts
# For now, I suppose that we could allow the systems to work on a "first come, first serve" basis
# The scripts could simply loop until a connection is available, and then proceed
# Otherwise, a separate script (or set of scripts) should be used to prioritize access to the MongoDB

try:
    conn = Connection()
    # db = conn['asyncAuvert']
    db = conn['auversion']

except:
    # print 'Error: Could not connect to the database \'asyncAuvert\''
    print 'Error: Could not connect to the database \'auversion\''
    exit(1)

connAvail = 0

try:
    connAvail = db.command('serverStatus')['connections']['available']

except:
    print 'Error: Could not retrieve the number of MongoDB connections available'
    exit(1)
    
mongoSema = BoundedSemaphore(value=(.25 * connAvail)) # Use 25% of the connections available

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
            print 'Warning: Bad exclusion argument passed.'

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
exit(auvertColls(AMFCOLLROOTPATH))
