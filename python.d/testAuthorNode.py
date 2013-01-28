#!/usr/bin/env python

from authorprofile import getFilePathForAunex,AMF_NS
from authorprofile.network import checkIfAuthorIsIdentified,getNumberOfAuthorsForDoc

from random import randint
from lxml import etree

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

    def __init__(self,rootNode,edges):

        self.root=rootNode
        self.root._isRoot.append(self)
        self.edges=edges
        self.nodes=[]
        for edge in self.edges:
            edge._neighborhoods.append(self)
            if (edge.u is not self.root) and (edge.u not in self.nodes):
                self.nodes.append(edge.u)
            if (edge.v is not self.root) and (edge.v not in self.nodes):
                self.nodes.append(edge.v)

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

    def __init__(self,u,v,weight):

        self.u=u
        u._edges.append(self)
        self.v=v
        v._edges.append(self)
        self.weight=weight
        self._neighborhoods=[]

class Node(Network):

    def __init__(self,value):

        self.value=value
        self._edges=[]
        self._isRoot=[]

class AuthorNode(Node):

    def __init__(self,authorName):
        
        self.amfFilePath=getFilePathForAunex(authorName)

        neighborhood=None

        try:
            Node.__init__(self,authorName)
        except:
            pass

        if self.amfFilePath:
            try:
                self.amfDoc=etree.parse(self.amfFilePath)
            except:
                print 'Raised'
                exit()
                pass

            self.neighborhood=self.getNeighborhood()


        pass

    def getNeighborhood(self):

        edgeValues={}

        # May want to abstract this for the AuthorNode child classes

        for amfText in self.amfDoc.xpath('/amf:amf/amf:text',namespaces=AMF_NS):
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

class networkExplorer:

    def __init__(self,initialNeighborhood,maxDistance=3):

        self.maxDistance=maxDistance
        self.initialNeighborhood=initialNeighborhood
        self.targetNode=initialNeighborhood.root

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

        primaryNeighborhood=self.initialNeighborhood
        maxDistance=self.maxDistance

        author=primaryNeighborhood.root
        tree=Tree(author)
        print 'Exploring the neighborhood containing the node',author.value
        tree.neighborhoods[0]=[primaryNeighborhood]
        pathIndex=0
        exploredDistance=0
        neighborhoodIndex=0
        neighborIndex=0

        for primaryAunexNode in primaryNeighborhood.nodes:
            print 'Exploring the neighborhood containing the node',primaryAunexNode.value,'at a distance of',exploredDistance + 1

            # Instantiate a new Path object
            try:
                tree.paths.append(Path(primaryNeighborhood.root,[primaryAunexNode],[primaryNeighborhood.getEdge(primaryNeighborhood.root,primaryAunexNode)]))
            except NetworkPathError:
                print 'Could not instantiate the Path object for the nodes',primaryNeighborhood.root,'and',primaryAunexNode

            print tree.paths[pathIndex].serialize_vema_json()

            neighborhood=self.getNeighborhoodForAunexNode(primaryAunexNode)

            if not neighborhood:
                print 'Could find no adjacent nodes for',primaryAunexNode.value
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
                print 'Exploring the neighborhood containing the node',currentAunex.value,'at a distance of',exploredDistance + 1

                # If there are no neighbors for this aunex (this would be a system error, but it should not interrupt the vertical calculations)
                tree.paths[pathIndex].addNode(tree.neighborhoods[neighborhoodIndex][exploredDistance].nodes[neighborIndex],tree.neighborhoods[neighborhoodIndex][exploredDistance].getEdge(currentAunex,tree.neighborhoods[neighborhoodIndex][exploredDistance].nodes[neighborIndex]))
                print 'This would be stored into a NoSQL JSON-based database:',tree.paths[pathIndex].serialize_vema_json()
                import pdb;pdb.set_trace()

                if exploredDistance == (maxDistance - 1):

                    pathIndex=tree.insertNewPath(pathIndex,STORE_PATHS)
                
                neighborhood=self.getNeighborhoodForAunexNode(currentAunex)
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

# Global constants for this script

# The root node
SOME_AUTHORCLAIM_USER=Node('someAuthorClaimUser')

# The tree being explored in the citation network
#TREE=Tree(n1)

# Individuals with whom 'someAuthorClaimUser' has directly collaborated
# Please see the structure of the example citation tree below
N2=Node('M. Rothbard')
N3=Node('J. M. Keynes')
N4=Node('G. Berkeley')

# For each edge between the AuthorClaim user and a node for an unidentified author, an Edge object is instantiated.
# Assume that the direction of this graph is from the AuthorClaim user to the anonymous-author nodes, and further into the network.
# Assume that the entire network is adirectional, acyclic graph (but, we're only exploring this network using AuthorClaim user-nodes as the root nodes of trees).

# The edge weights are arbitrary values for this example.
# The edge weights are calculated using an algorithm developed/published by Mark J. Newman
# The general approach was outlined in the work, An Introduction to Network Theory (2010, p. 67)
# The algorithm appears to be a variation upon Google's PageRank algorithm
# SUM(1/(k - 1)) for each paper upon which both authors have collaborated
#     where k = SUM(all authors specified for in a given work)
# It was T. Krichels' decision to implement this algorithm (as well as most of the design of this network exploration process).

E1=Edge(SOME_AUTHORCLAIM_USER,N2,0.9)
E2=Edge(SOME_AUTHORCLAIM_USER,N3,0.5)
E3=Edge(SOME_AUTHORCLAIM_USER,N4,0.3)

# Neighborhood objects are instantiated given a Node object, and a list of Edge objects

print AuthorNode('Bernardo Batiz-Lazo').neighborhood
exit()

MAX_DISTANCE=4
try:
    networkExplorer(Neighborhood(SOME_AUTHORCLAIM_USER,[E1,E2,E3]),MAX_DISTANCE).explore()
except NetworkExplorationError:
    print 'Could not explore the tree for this node in the citation network.'

# Original notes

# The exploration of the network requires the exploration of networks
# Explore networks to (n, maxDistance - 1)
# As each network is explored, discover the path between the root node and the neighborhood node
# For each path discovered, evaluate the path (e. g. compare with other paths, use the poma, etc.)
# After evaluating the path, serialize it if necessary (to be implemented)
# O   O
# |  / neighborhood for (n, 1) consists of all aunexes neighboring n aunex, found 2 steps from the root node
# O O
# |/   neighborhood for (0, 0) consists of all aunexes found at a distance of 1 step from the root node
# O
