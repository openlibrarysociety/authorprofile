#!/usr/bin/env python

from random import randint

import pdb
from time import time
from authorprofile import AuthorClaimUser,normalizeAunex,getFilePathForAunex,AMF_NS,AUTHORCLAIM_USERS_MONGODB_COLL,AUTHORS_MONGODB_COLL
#from authorprofile.network import Node,Edge,Neighborhood
from authorprofile import getMongoDBConn,getMongoDBColl,AMF_NS
#from authorprofile.network import checkIfAuthorIsIdentified,getNumberOfAuthorsForDoc


from string import punctuation
from lxml import etree
from re import sub,search,escape

# Constants
STORE_PATHS=0

class NetworkExplorationError(StandardError):

    def __init__(self):

        #[...]
        pass

class NetworkNeighborhoodError(NetworkExplorationError):

    def __init__(self):

        #[...]
        pass

class NetworkPathError(NetworkExplorationError):

    def __init__(self):

        #[...]
        pass

class Network:
    
    def __init__(self,_id=0):

        # [...]
        self.components=[]
        pass

class Component:

    def __init__(self,_id=0):

        # [...]
        self.trees=[]
        self.residentNodes=[]
        pass

class Tree(Network):

    def __init__(self,rootNode,paths=None,neighborhoods=None):

        self.paths=[]
        self.neighborhoods=[[]]
        self.root=rootNode
        self.root._isRoot.append(self)
        pass

    def insertNewPath(self,pathIndex,STORE_PATHS=0,offset=1):

        # Clone the path.
        self.paths.append(self.paths[pathIndex])
        # For this implementation, do NOT retain objects instantiated for discovered paths in the heap.
        if not STORE_PATHS:
            self.paths[pathIndex]=None
        # For reference, future implementations will integrate the permanent serialization of path structures into the database.
        # This will allow for more intensive methods of network analysis to be undertaken using the database values themselves.
        pathIndex+=1
        # Remove the last node of the cloned path.
        for i in range(offset):
            self.paths[pathIndex].removeNode(len(self.paths[pathIndex].nodes) - 1)

        return pathIndex

class Neighborhood(Network):

    def getNodes(self):

        if not self.nodes:
            for edge in self.edges:
                for n in set(['u','v']):
                    print getattr(edge,n).value;print self.root.value
                    print getattr(edge,n).value != self.root.value
                    #import pdb;pdb.set_trace()
                    if getattr(edge,n).value != self.root.value:
                        self.nodes.append(getattr(edge,n))

                    # Debug
                    # This should be be called
                    #else:
                        #print 'avoided'
                        #print self.root
                        #import pdb;pdb.set_trace()

    def __init__(self,rootNode=None,edges=None,jsonObj=None,discoveredNodes=None):

        self.edges=[]
        self.nodes=[]

        if jsonObj:

            for jsonEdge in jsonObj['edges']:
                self.edges.append(Edge(jsonObj=jsonEdge,rootNode=rootNode))
                self.root=rootNode
                self.getNodes()

        else:

            self.root=rootNode
            self.root._isRoot.append(self)
            self.edges=edges
            self.getNodes()
            #for edge in self.edges:
            #    edge._neighborhoods.append(self)
                
            #    if (edge.u is not self.root) and (edge.u not in self.nodes):
            #        for n in set(['u','v']):
            #            self.nodes.append
            #        self.nodes.append(edge.u)
            #    if (edge.v is not self.root) and (edge.v not in self.nodes):
            #        self.nodes.append(edge.v)

    def getEdges(self,u,v):
        edges=[]
        for edge in self.edges:
            if (edge.u == u and edge.v == v) or (edge.u == v and edge.v == u):
                edges.append(edge)
        return edges

    def getEdge(self,u,v):
        for edge in self.edges:
            if (edge.u == u and edge.v == v) or (edge.u == v and edge.v == u):
                return edge

    def getJSONForIterAttr(self,attrName):
        attrIterJSON=[]

        for attrItem in getattr(self,attrName):
            attrIterJSON.append(attrItem.toJSON())

        return attrIterJSON

    def getJSONForIterAttrs(self,attrNames):

        attrItersJSON={}
        for attrName in attrNames:
            attrItersJSON[attrName]=self.getJSONForIterAttr(attrName)

        return attrItersJSON

    def toJSON(self):

        # I'm not serializing the 'nodes' attribute, as AuthorNodes already serialize Neighborhood objects
        # Neighborhood objects are serialized for performance purposes only; AuthorNode and AuthorClaimUserNode objects are what must be ultimately serialized as representations of nodes within the citation network
        neighborhoodJSON=self.getJSONForIterAttrs(['edges'])
        neighborhoodJSON['class']=Neighborhood.__name__

        return neighborhoodJSON

        # If it were only this simple...
        # return {'class':Neighborhood.__name__,'edges':self.edges}

    def __repr__(self):
        return unicode(self.toJSON())
    

class Path(Network):

    def __init__(self,rootNode,nodes,edges,neighborhoods=None,weight=0):
        self.root=rootNode

        # Construct the path
        i=0
        self.edges=[]
        self.weight=0

        # Example:
        # For the (identified) AuthorClaim user J. Smith...
        #
        # root node: J. Smith
        #
        # ...we find that J. Smith has authored a work with two unidentified authors: A. Jones and C. Brown...
        #
        # nodes: A. Jones, C. Brown
        #
        # ...constituting a neighborhood within the citation network...
        #
        # neighborhood 1: J. Smith, A. Jones, C. Brown
        #
        # ...exploring further, we find that A. Jones has authored another work with C. Brown, and also with F. Thompson:
        #
        # neighborhood 2: A. Jones, C. Brown, F. Thompson

        # In neighborhood 1, look for an edge between J. Smith and A. Jones
        # (iterate)
        # In neighborhood 1, look for an edge between A. Jones and C. Brown

        # As a result, Paths should be instantiated from Edges

        if not edges:
            self.nodes=[self.root] + nodes
            self.neighborhoods=neighborhoods
            # For a single neighborhood...
            for neighborhood in self.neighborhoods:
                while i < len(self.nodes) - 1:
                    # where node[i] is u and node[i+1] is v in edges
                    edge=neighborhood.getEdge(self.nodes[i],self.nodes[i+1])
                    if edge:
                        self.edges.append(edge)
                    i+=1
                if edges and (len(edges) >= len(self.nodes)):
                    break
        else:
            self.nodes=nodes
            self.edges=edges
        self.distanceFromRoot=len(self.nodes)


        for edge in self.edges:
            
            self.weight+=edge.weight

    def addNode(self,node,edge):

        try:

            self.edges.append(edge)
            self.nodes.append(node)

        except:

            return None
        self.distanceFromRoot=len(self.nodes)

    def removeNode(self,nodeIndex):

        try:

            self.nodes.pop(nodeIndex)
            self.edges.pop(nodeIndex)
        except:

            return None
        self.distanceFromRoot=len(self.nodes)
        
    def serialize_vema_json(self):

        # This associative array structure was originally designed by T. Krichel, and implemented in Perl.
        # I've renamed the names of the keys for the purposes of comprehensibility.
        # Originally:
        # 'path_weight' was 'w'
        # 'path' was 'p'
        # 'distance_from_tree_root_node' was 'd'
        # 'tree_root_node' was 'e'
        # If you query the MongoDB collection authorprofile.vertical at authorprofile.org, you will find this associative array structure serialized for the discovered paths
        #
        # For the purposes of preserving interoperability with the legacy design, it has been preserved.
        # It will be reduced to an attribute for the authorprofile.AuthorNode object when the API has been fully implemented.
        
        p=''
        i=len(self.nodes) - 1
        while i >= 0:
            p+=self.nodes[i].value
            p+='_'
            i-=1
        p+=self.root.value
        return {'aunex':self.nodes[len(self.nodes) - 1].value,'tree_root_node':self.root.value,'distance_from_tree_root_node':self.distanceFromRoot,'path':p,'path_weight':self.weight}

class Edge(Network):


    def __init__(self,u=None,v=None,weight=None,jsonObj=None,rootNode=None):

        if jsonObj:

            for n in set(['u','v']):
                if jsonObj[n] == rootNode.value:
                    setattr(self,n,rootNode)
                else:
                    setattr(self,n,AuthorNode(jsonObj[n]))
                #if not getattrself.n:
                #    print 'Could not instantiate Edge for',jsonObj['u'],'and',jsonObj['v']
                    

            self.weight=jsonObj['weight']

        else:
            self.u=u
            u._edges.append(self)
            self.v=v
            v._edges.append(self)
            self.weight=weight
            self._neighborhoods=[]

    def toJSON(self):
        return {'u':self.u.value,'v':self.v.value,'weight':self.weight}

    def __repr__(self):

        return unicode(self.toJSON())

        # Unicode handling
        #try:
        #    return 'An edge for the nodes '+str(self.u)+' and '+str(self.v)+' with a weight '+str(self.weight)
        #except:
        #    return 'To be implemented: Unicode handling'
        #    pass

class Node(Network):

    def __init__(self,value):

        self.value=unicode(value)
        self._edges=[]
        self._isRoot=[]

    def __repr__(self):
        return self.value

class networkExplorer:

    #def __init__(self,initialNeighborhood,maxDistance=3):
    def __init__(self,authorClaimUser,maxDistance=3):

        self.author=authorClaimUser
        self.maxDistance=maxDistance
        self.initialNeighborhood=self.author.neighborhood

    # I didn't want to extend this to include the XML parsing process which is used to explore the network for a given node.
    def getNeighborhoodForAunexNode(self,aunexNode):
        
        # The example citation tree:

        # A. N. Whitehead    L. von Mises                                  # Depth = 4
        #       \      /     
        #   J. Habermas  D. Hume                                       # Depth = 3
        #         \     /
        #     G. Lukacs   J. J. Rousseau                               # Depth = 2
        #          \     /
        #        M. Rothbard                 J. M. Keynes  G. Berkeley # Depth = 1
        #           \                       /             /
        #            \                     /            /
        #             \                              /
        #              \                          /
        #               \                     /
        #              someAuthorClaim user

        if aunexNode.value == 'M. Rothbard':
            n6=Node('G. Lukacs')
            n7=Node('J. J. Rousseau')
            return Neighborhood(aunexNode,[Edge(aunexNode,n6,0.4),Edge(n6,n7,0.4),Edge(n7,aunexNode,0.8)])

        if aunexNode.value == 'G. Lukacs':
            n8=Node('J. Habermas')
            n9=Node('D. Hume')
            return Neighborhood(aunexNode,[Edge(aunexNode,n8,0.4),Edge(n8,n9,0.4),Edge(n9,aunexNode,0.8)])

        if aunexNode.value == 'J. Habermas':
            n10=Node('A. N. Whitehead')
            n11=Node('L. von Mises')
            return Neighborhood(aunexNode,[Edge(aunexNode,n10,0.4),Edge(n10,n11,0.4),Edge(n11,aunexNode,0.8)])

        else:
            return

    # The primary neighborhood for any given AuthorClaim user is absolutely essential to the network exploration process.
    def explore(self):

#        primaryNeighborhood=self.initialNeighborhood
#        author=primaryNeighborhood.root

        maxDistance=self.maxDistance
        author=self.author
        primaryNeighborhood=author.neighborhood

        # The number of nodes discovered on a given branch
        self.discoveredNodes=[]

        tree=Tree(author)
        print 'Exploring the tree for the AuthorClaim user',author.value
        tree.neighborhoods[0]=[primaryNeighborhood]
        pathIndex=0
        exploredDistance=0
        neighborhoodIndex=0
        neighborIndex=0


        for primaryAunexNode in primaryNeighborhood.nodes:

            self.discoveredNodes.append(primaryAunexNode)

            print 'Exploring the neighborhood containing the node',primaryAunexNode.value,'at a distance of',exploredDistance + 1

            # Instantiate a new Path object
            try:
                tree.paths.append(Path(primaryNeighborhood.root,[primaryAunexNode],[primaryNeighborhood.getEdge(primaryNeighborhood.root,primaryAunexNode)]))
            except NetworkPathError:
                print 'Could not instantiate the Path object for the nodes',primaryNeighborhood.root,'and',primaryAunexNode


            #neighborhood=self.getNeighborhoodForAunexNode(primaryAunexNode)
            neighborhood=primaryAunexNode.getNeighborhood(self.discoveredNodes)


            if not neighborhood:
                print 'Could find no adjacent nodes for',primaryAunexNode.value
                self.discoveredNodes=[]
                pathIndex+=1
                neighborhoodIndex+=1
                continue

            try:
                # We go further into the network by retrieving all neighbors for the first non-root node in the neighborhood...
                tree.neighborhoods[neighborhoodIndex].append(neighborhood)

            except NetworkNeighborhoodError:
                print 'Could not store the Neighborhood object into the Tree object'

            exploredDistance=1


            # Evaluate the path
            # To do: Implement tree.addPath(arguments for creating Path object)
            # This evaluates the path, and then serializes the path

            # Exploring the network by 1 binary step

            while True:

                # If this is the last node within the current neighborhood
                if neighborIndex >= len(tree.neighborhoods[neighborhoodIndex][exploredDistance].nodes):


                    if exploredDistance == 1:
                        break

                    # Otherwise, set the neighborIndex to the index value of the root node of the current neighborhood within the neighborhood at a distance of 1 step closer to the root node
                    neighborIndex=tree.neighborhoods[neighborhoodIndex][exploredDistance - 1].nodes.index(tree.neighborhoods[neighborhoodIndex][exploredDistance].root)
                    # If this is the last index in the neighborhood, then loop until you arrive at a node which is not the last in the neighborhood
                    while (neighborIndex + 1) > len(tree.neighborhoods[neighborhoodIndex][exploredDistance].nodes):

                        exploredDistance-=1
                        neighborIndex=tree.neighborhoods[neighborhoodIndex][exploredDistance - 1].nodes.index(tree.neighborhoods[neighborhoodIndex][exploredDistance].root)
                    # Set the neighborhood to this previous index
                    neighborIndex+=1
                    # Decrement the distance explored
                    exploredDistance-=1
                    pathIndex=tree.insertNewPath(pathIndex,offset=(maxDistance - (exploredDistance + 1)))
                    continue

                currentAunex=tree.neighborhoods[neighborhoodIndex][exploredDistance].nodes[neighborIndex]

                self.discoveredNodes.append(currentAunex)

                print 'Exploring the neighborhood containing the node',currentAunex.value,'at a distance of',exploredDistance + 1

                # If there are no neighbors for this aunex (this would be a system error, but it should not interrupt the vertical calculations)
                tree.paths[pathIndex].addNode(tree.neighborhoods[neighborhoodIndex][exploredDistance].nodes[neighborIndex],tree.neighborhoods[neighborhoodIndex][exploredDistance].getEdge(currentAunex,tree.neighborhoods[neighborhoodIndex][exploredDistance].nodes[neighborIndex]))
                print 'This would be stored into a NoSQL JSON-based database:',tree.paths[pathIndex].serialize_vema_json()
                
                import pdb;pdb.set_trace()

                if exploredDistance == (maxDistance - 1):

                    pathIndex=tree.insertNewPath(pathIndex,STORE_PATHS)
                
                #neighborhood=self.getNeighborhoodForAunexNode(currentAunex)
                neighborhood=currentAunex.getNeighborhood(self.discoveredNodes)
                if not neighborhood:

                    neighborIndex+=1
                    continue
                try:

                    # We go further into the network by retrieving all neighbors for the first non-root node in the neighborhood...
                    tree.neighborhoods[neighborhoodIndex].append(neighborhood)
                except NetworkNeighborhoodError:
                    print 'Could not store the Neighborhood object into the Tree object'

                exploredDistance+=1
                continue

            # Only increment the exploration distance after the neighbors have been successfully retrieved



            # D---E (The neighbors for D are [E, B]
            # |  /
            # B-C   (The neighbors for B are [D, C, A]
            # |/
            # A     (The neighbors for A are [B, C]

            # Remember: root nodes are not contained within neighborhood.node
            pathIndex+=1
            neighborhoodIndex+=1
            neighborIndex=0
            exploredDistance=0
        
        print 'Tree in the citation network explored for',author.value

# No Document Resource modules were found which integrate with the MongoDB.

def getACUserRecordForACISID(acisID):

    conn=getMongoDBConn()
    record=getMongoDBColl(AUTHORCLAIM_USERS_MONGODB_COLL,conn).find_one({'acisID':acisID})
    
    conn.disconnect()
    return record

def getACUserRecordForNameVar(authorNameStr,conn):

    # I do not know what the ACIS string-normalization process resembles.
    #authorNameStr=sub('['+escape(punctuation)+']','',authorNameStr.lower())
    authorNameStr=normalizeAunex(authorNameStr)

    return getMongoDBColl(AUTHORCLAIM_USERS_MONGODB_COLL,conn).find_one({'nameVariations':authorNameStr})
    
def checkIfACUserHasClaimedText(authorNameStr,amfText):

    # I do not know what the ACIS string-normalization process resembles.
    #authorNameStr=sub('['+escape(punctuation)+']','',authorNameStr.lower())
    authorNameStr=normalizeAunex(authorNameStr)

    conn=getMongoDBConn()
    record=getACUserRecordForNameVar(authorNameStr,conn)
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

        # Deprecated
        #if acisID:
        #    conn=getMongoDBConn()
        #    if not getACUserRecordForACISID(acisID):

        #        return AuthorNode(acisID)
        #        pass
        #    conn.disconnect()
        

        try:
            AuthorClaimUser.__init__(self,amfFilePath,acisID,noDBUpdate)

        except:
            print 'Raise'
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

        # Retrieve the serialized object attribute
        print type(self.retrieveAttrFromDBColl('neighborhood'))
        neighborhood=Neighborhood(rootNode=self,jsonObj=self.retrieveAttrFromDBColl('neighborhood'))
        if neighborhood:return neighborhood

        edgeValues={}

        for amfText in self.amfDoc.xpath('/amf:amf/amf:person/amf:isauthorof/amf:text',namespaces=AMF_NS):
            for amfName in amfText.xpath('amf:hasauthor/amf:person/amf:name',namespaces=AMF_NS):
                # Check AuthorClaim profiles to determine whether or not this text has been claimed by any users.
                # If it has, retrieve the name variations for the user and compare with the author-name string.
                # These relationships should be stored into an object and serialized for future reference.

                if checkIfACUserHasClaimedText(amfName.text,amfText): continue

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

            # Debug
            # This works
            # getMongoDBColl('debugNeighborhood',getMongoDBConn()).update({'acisID':self.value},{'$set':Neighborhood(self,[Edge(self,AuthorNode(author),0),Edge(self,AuthorNode(author),0)]).toJSON()},True,safe=True)
            # This works as well
            #self.neighborhood=Neighborhood(self,[Edge(self,AuthorNode(author),0),Edge(self,AuthorNode(author),0)])
            #getMongoDBColl('debugNeighborhood',getMongoDBConn()).update({'acisID':self.value},{'$set':{'neighborhood':getattr(self,'neighborhood').toJSON()}},True,safe=True)            
            #import pdb;pdb.set_trace()
            
            edges.append(Edge(self,AuthorNode(author),edgeValues[author]))
            # Memory
            del edgeValues[author]

        # Serialize the network?
        # If neighborhood.timeLastUpdated < authorClaimUserProfiles.timeLastUpdated: regenerate

        # Debug

        self.neighborhood=Neighborhood(self,edges)
        self.updateAttrInMongoDBColl('neighborhood')
            
        return self.neighborhood

    def updateAttrInMongoDBColl(self,attrName,collName=AUTHORCLAIM_USERS_MONGODB_COLL):

        # Debug
        #conn=getMongoDBConn()
        # Must be set explicitly to JSON in order to avoid the seg fault?
        # Debug 

        # bson.errors.InvalidDocument: Cannot encode object: Liu, Xiaoming
        # print getattr(self,attrName).toJSON()
        # This works
        # getMongoDBColl('debugDictList',getMongoDBConn()).update({'a':True},{'$set':{'e':[{'a':'b'},{'c':'d'}]}},True,safe=True)
        

        #getMongoDBColl(collName,conn).update({'acisID':self.value},{'$set':{attrName:getattr(self,attrName).toJSON()}},True,safe=True)
        #conn.disconnect()

        conn=getMongoDBConn()
        try:
            getMongoDBColl(collName,conn).update({'acisID':self.value},{'$set':{attrName:getattr(self,attrName).toJSON()}},True,safe=True)
        except:
            print 'Could not update'
            raise
        conn.disconnect()
        print 'Updated'
        exit()

    def retrieveAttrFromDBColl(self,attrName,collName=AUTHORCLAIM_USERS_MONGODB_COLL):

        conn=getMongoDBConn()
        try:
            record=getMongoDBColl(collName,conn).find_one({'acisID':self.value},{attrName:True})
        except:
            print 'Could not retrieve the attribute',attrName,'for',self.value
            exit(1)
            #raise
        if record and (attrName in record):return record[attrName]
        conn.disconnect()

    def __repr__(self):
        return self.value

class AuthorNode(Node):
    
    def __init__(self,authorName):
        
        print 'Discovered an author',authorName

        self.amfFilePath=getFilePathForAunex(authorName)

        if self.amfFilePath:
            print 'Found',self.amfFilePath,'as auversion file path for',authorName
        else:
            print 'Could not find the auversion file path for',authorName

        self.amfDoc=None

        try:
            Node.__init__(self,authorName)
        except:
            pass

        if self.amfFilePath:
            self.amfDoc=etree.parse(self.amfFilePath)
            try:
                self.amfDoc=etree.parse(self.amfFilePath)
            except:
                print 'Raised'
                exit()
                pass

            #self.neighborhood=self.getNeighborhood()


    def getNeighborhood(self,discoveredNodes):

        if not self.amfDoc:return None

        # Too many problems with the JSON serialization
        #neighborhood=self.retrieveAttrFromDBColl('neighborhood',collName=AUTHORS_MONGODB_COLL)

        #neighborhood=self.unpickleFromFile()
        #if neighborhood:return neighborhood

        edgeValues={}

        # May want to abstract this for the AuthorNode child classes

        for amfText in self.amfDoc.xpath('/amf:amf/amf:text',namespaces=AMF_NS):
            print amfText.get('ref'),'associates the following authors:',

            for amfName in amfText.xpath('amf:hasauthor/amf:person/amf:name',namespaces=AMF_NS):

                if amfName.text in discoveredNodes:continue

                print amfName.text

                # Check AuthorClaim profiles to determine whether or not this text has been claimed by any users.
                # If it has, retrieve the name variations for the user and compare with the author-name string.
                # These relationships should be stored into an object and serialized for future reference.
                if checkIfACUserHasClaimedText(amfName.text,amfText):
                    print amfName.text,'is an AuthorClaim user'
                    continue

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
            edges.append(Edge(self,AuthorNode(author),edgeValues[author]))
            # Memory
            del edgeValues[author]

        self.neighborhood=Neighborhood(self,edges)
        print 'Neighborhood explored for',self.value
        # Serialize the network ?
        # If the structure of the network is always changing, then this is pointless
        # If neighborhood.timeLastUpdated < 3lib.timeLastUpdated: regenerate

        # This does not work
        # (Problem serializing the object into JSON)
        #self.updateMongoDBColl(collName=AUTHORS_MONGODB_COLL)

        # For debugging purposes, pickle the AuthorNode
        #self.pickleToFile()

        return self.neighborhood

    def toJSON(self):

        return {'class':AuthorNode.__name__,'name':self.value,'amfFilePath':self.amfFilePath,'neighborhood':self.neighborhood,'timeLastUpdated':time()}

    def updateMongoDBColl(self,collName=AUTHORS_MONGODB_COLL):

        # print unicode(self.toJSON()).encode('ascii','backslashreplace')
        #print self.toJSON()

        conn=getMongoDBConn()
        try:
            return getMongoDBColl(collName,conn).update({'name':self.value},{'$set':{'name':self.value}},True,safe=True)
        except:
            print 'Could not update'
            exit()
            raise
        conn.disconnect()
        print 'Updated'
        exit()

    def retrieveAttrFromDBColl(self,attrName,collName=AUTHORS_MONGODB_COLL):

        conn=getMongoDBConn()
        try:
            record=getMongoDBColl(collName,conn).find_one({'name':self.value},{attrName:True})
        except:
            print 'Could not retrieve'
            raise
        if attrName in record:return record[attrName]
        conn.disconnect()

print networkExplorer(AuthorClaimUserNode(acisID='pkr1')).explore()
