#!/usr/bin/env python

from authorprofile import AuthorClaimUser,normalizeAunex,AUTHORCLAIM_USERS_MONGODB_COLL
from authorprofile.network import Node,Edge,Neighborhood
from authorprofile.common import getMongoDBConn,getMongoDBColl,AMF_NS

from string import punctuation
from lxml import etree
from re import sub,search,escape

# No Document Resource modules were found which integrate with the MongoDB.

def checkIfAuthorIsIdentified(authorNameStr,amfText):

    # I do not know what the ACIS string-normalization process resembles.
    #authorNameStr=sub('['+escape(punctuation)+']','',authorNameStr.lower())
    authorNameStr=normalizeAunex(authorNameStr)

    conn=getMongoDBConn()

    record=getMongoDBColl('authorprofile',AUTHORCLAIM_USERS_MONGODB_COLL,conn).find_one({'nameVariations':authorNameStr})
    conn.disconnect()
    
    if not record:return record

    return amfText.get('ref') in record['isauthorofTexts']

def getNumberOfAuthorsForDoc(amfText):
    #print [s.tag for s in amfName.getparent().getparent().itersiblings()]
    #return len(amfName.getparent().getparent().itersiblings())

    try:
        return len(amfText.xpath('amf:hasauthor/amf:person/amf:name',namespaces=AMF_NS))
    except:
        pass

def getNumberOfAuthorsForPaper(paper=None,authorNode=None,amfDoc=None):

    if paper.amfTextID:

        paper.amfFilePath=getFilePathForAMFTextID(self.amfTextID)
        pass

    if paper.amfFilePath and not amfDoc:
        try:

            amfDoc=etree.parse(paper.amfFilePath)
        except:
            
            print 'Error: Could not parse',paper.amfFilePath
            exit()

        for amfTextElement in amfDoc.xpath('/amf:amf/amf:text',namespaces=AMF_NS):
            return len(amfTextElement.xpath('amf:hasauthor',namespaces=AMF_NS))
    else:

        print 'Error: Not yet implemented'
        exit()

class AuthorClaimUserNode(AuthorClaimUser,Node):

    def __init__(self,amfFilePath=None,acisID=None,noDBUpdate=True):

        try:
            AuthorClaimUser.__init__(self,amfFilePath,acisID,noDBUpdate)

        except:
            # Couldn't invoke the constructor for AuthorClaimUser
            pass

        try:
            Node.__init__(self,acisID)

        except:
            # Couldn't invoke the constructor for Node
            pass

        # AuthorClaim users belong only to one neighborhood in their tree
        self.neighborhood=self.getNeighborhood()

    def getNeighborhood(self):

        edgeValues={}

        for amfText in self.amfDoc.xpath('/amf:amf/amf:person/amf:isauthorof/amf:text',namespaces=AMF_NS):
            for amfName in amfText.xpath('amf:hasauthor/amf:person/amf:name',namespaces=AMF_NS):
                # Check AuthorClaim profiles to determine whether or not this text has been claimed by any users.
                # If it has, retrieve the name variations for the user and compare with the author-name string.
                # These relationships should be stored into an object and serialized for future reference.
                if checkIfAuthorIsIdentified(amfName.text,amfText): continue
                
                # T. Krichel's weight design
                # Derived from the work of Mark J. Newman and Google PageRank
                
                k=float(getNumberOfAuthorsForDoc(amfText))
                
                # Handle division by zero
                if k-1:
                    if amfName.text in edgeValues:
                        edgeValues[amfName.text]+1/(k-1)
                    else:
                        edgeValues[amfName.text]=1/(k-1)
                # Handle division by zero
                else:
                    if not amfName.text in edgeValues: edgeValues[amfName.text]=0

        # From this structure, instantiate the Path objects
        edges=[]
        for author in edgeValues.keys():
            edges.append(Edge(self,Node(author),edgeValues[author]))
            # Memory
            del edgeValues[author]

        return Neighborhood(self,edges)

#print AuthorClaimUserNode(acisID='pkr1',noDBUpdate=False)
print AuthorClaimUserNode(acisID='pto3').neighborhood
