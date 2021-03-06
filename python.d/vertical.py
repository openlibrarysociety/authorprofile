#!/usr/bin/env python

from random import randint

class Network:
    
    def __init__(self,_id=0):

        self._id=randint(1,16^8)

class Tree(Network):

    def __init__(self,rootNode,paths=None,neighborhoods=None):

        self.paths=[]
        self.neighborhoods=[[]]
        self.root=rootNode
        self.root._isRoot.append(self)
        pass

    def insertNewPath(self,pathIndex,STORE_PATHS=0,offset=1):

        # Clone the path
        self.paths.append(self.paths[pathIndex])
        # Do not retain evaluated paths in memory
        if not STORE_PATHS:
            self.paths[pathIndex]=None
        pathIndex+=1
        # Remove the last node of the cloned path
        for i in range(offset):
            self.paths[pathIndex].removeNode(len(self.paths[pathIndex].nodes) - 1)

        return pathIndex

class Neighborhood(Network):

    # def __init__(self,edgesMap):
    def __init__(self,rootNode,edges):

        self.root=rootNode
        self.root._isRoot.append(self)
        self.edges=edges
        self.nodes=[]
        for edge in self.edges:
            edge._neighborhoods.append(self)
            if (edge.u is not self.root) and (edge.u not in self.nodes):
            #if edge.u not in self.nodes:
                self.nodes.append(edge.u)
            if (edge.v is not self.root) and (edge.v not in self.nodes):
            #if edge.v not in self.nodes:
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

    def deprecated(self):

        self.root=rootNode
        self.edges=edges
        self.nodes=[]

        for edge in edges:
            # for edgeNode in :
                # if edgeNode not in self.nodes:
            print edge.u.value, edge.v.value
            if edge.u not in self.nodes:
                self.nodes.append(edge.u._id)
            else:
                self.root=edge.u
            if edge.v not in self.nodes:
                self.nodes.append(edge.v._id)

            # Acyclic, unidirectional
            for node in self.nodes:
                if self.nodes.count(node) > 1:
                    self.root=edge.v

        if not self.root:
            print 'Fatal: Could not find root node for edge'
            exit()

class Path(Network):

    def __init__(self,rootNode,nodes,edges,neighborhoods=None,weight=0):
        self.root=rootNode

        # Construct the path
        i=0
        self.edges=[]
        self.weight=0

        # e. g.
        # root: alpha
        # nodes: beta, gamma
        # neighborhood 1: alpha, beta, gamma
        # neighborhood 2: beta, gamma, delta

        # In neighborhood 1, look for an edge between alpha and beta
        # (iterate)
        # In neighborhood 1, look for an edge between beta and gamma
        # Edges

        # As a result, Paths should be instantiated from Edges

        if not edges:
            self.nodes=[self.root] + nodes
            print 'Fatal: Not implemented'
            exit()
            self.neighborhoods=neighborhoods
            # For a single neighborhood
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
        
        p=''
        #for node in self.nodes:
        i=len(self.nodes) - 1
        while i >= 0:
            p+=self.nodes[i].value
            p+='_'
            i-=1
        p+=self.root.value
        return {'aunex':self.nodes[len(self.nodes) - 1].value,'e':self.root.value,'d':self.distanceFromRoot,'p':p,'w':self.weight}

class Edge(Network):

    def __init__(self,u,v,weight):

        # super(Edge,self).__init__()
        self.u=u
        u._edges.append(self)
        self.v=v
        v._edges.append(self)
        self.weight=weight
        self._neighborhoods=[]

class Node(Network):

    def __init__(self,value):

        # super(Node,self).__init__()
        self._id=randint(1,16^8)
        self.value=value
        self._edges=[]
        self._isRoot=[]

# I didn't want to extend this to include the XML parsing process which is used to explore the network for a given node.
def getNeighborhoodForAunexNode(aunexNode):

    if aunexNode.value == 'neill':
        n6=Node('charles')
        n7=Node('eric')
        return Neighborhood(aunexNode,[Edge(aunexNode,n6,0.4),Edge(n6,n7,0.4),Edge(n7,aunexNode,0.8)])

    if aunexNode.value == 'charles':
        n8=Node('phillip')
        n9=Node('frederick')
        return Neighborhood(aunexNode,[Edge(aunexNode,n8,0.4),Edge(n8,n9,0.4),Edge(n9,aunexNode,0.8)])

    if aunexNode.value == 'phillip':
        n10=Node('louis')
        n11=Node('connor')
        return Neighborhood(aunexNode,[Edge(aunexNode,n10,0.4),Edge(n10,n11,0.4),Edge(n11,aunexNode,0.8)])


# the root node
n1=Node('pjg1')

tree=Tree(n1)

#get the XML strings

# for each name element, a Node object is instantiated
n2=Node('neill')
n3=Node('robert')
n4=Node('alfred')

# for each link between the author and the aunex, an Edge object is instantiated
# assume that the direction is from the author to the aunexes, and from an aunex, deeper into the network
# assume a bidirectional, acyclic graph
e1=Edge(n1,n2,0.9)
e2=Edge(n1,n3,0.5)
e3=Edge(n1,n4,0.3)

nbrhd1=Neighborhood(n1,[e1,e2,e3])

STORE_PATHS=0

def getVertical(primaryNeighborhood):

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
        except:
            print 'Fatal: Could not instantiate the path between',primaryNeighborhood.root,'and',primaryAunexNode
            exit()

        print tree.paths[pathIndex].serialize_vema_json()

        neighborhood=getNeighborhoodForAunexNode(primaryAunexNode)

        if not neighborhood:

            print 'Could find no adjacent nodes for',primaryAunexNode.value
            pathIndex+=1
            neighborhoodIndex+=1
            continue

        try:

            # We go further into the network by retrieving all neighbors for the first non-root node in the neighborhood...
            tree.neighborhoods[neighborhoodIndex].append(neighborhood)
        except:

            print 'Fatal'
            exit()
        exploredDistance=1

        # Evaluate the path
        # To do: Implement tree.addPath(arguments for creating Path object)
        # This evaluates the path, and then serializes the path

        # Exploring the network by 1 binary step
        #while exploredDistance < maxDistance:

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
            print tree.paths[pathIndex].serialize_vema_json()

            if exploredDistance == (maxDistance - 1):

                pathIndex=tree.insertNewPath(pathIndex,STORE_PATHS)
                
            neighborhood=getNeighborhoodForAunexNode(currentAunex)
            if not neighborhood:

                neighborIndex+=1
                continue
            try:

                # We go further into the network by retrieving all neighbors for the first non-root node in the neighborhood...
                tree.neighborhoods[neighborhoodIndex].append(neighborhood)
            except:

                print 'Fatal'
                exit()

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
        
    exit()

maxDistance=4
getVertical(Neighborhood(n1,[e1,e2,e3]))


def deprecated_2():

    # Then, remove the neighbors which have already been found for the aunex at the previous neighborhood
    # Find all nodes from tree.neighborhoods[0 - neighborhoodIndex][0 - exploredIndex]
    
    # removeExploredAuthorNodes
    i=0
    j=0
            #print len(tree.neighborhoods) - 1
            #print tree.neighborhoods[0]
            # IF LENGTH OF NEIGHBORHOODS = 0, ITERATE ONCE
            # IF LENGTH OF NEIGHBORHOODS = 1, ITERATE ONCE
            #print len(tree.neighborhoods[0]) - 1
            #print tree.neighborhoods[0][0:1]
            #exit()
            #print (len(tree.neighborhoods)) - 1
    #tree.neighborhoods.append('test')
            #print (len(tree.neighborhoods)) - 1
            #exit()
    #        while i < (len(tree.neighborhoods) - 1):

    #            print 'a',tree.neighborhoods[i]
                #for j in tree.neighborhoods[i][0:len(tree.neighborhoods) - 1]:
                #for j in tree.neighborhoods[i][0:len(tree.neighborhoods[i])]:
    #            while j < (len(tree.neighborhoods[i]) - 1):

    #                print 'b',tree.neighborhoods[i][j]
    #                for authorNode in tree.neighborhoods[i][j].nodes:
    #                    exploredAuthorNodes.append(authorNode)
    #                j+=1
    #            i+=1
    #        print exploredAuthorNodes
    #        print len(tree.neighborhoods)
    #        print len(tree.neighborhoods[0])

    #print 'DEBUG',tree.neighborhoods[neighborhoodIndex]

    #        for n in tree.neighborhoods[neighborhoodIndex][exploredDistance].nodes:
    #            print n.value

    #        exit()


# The exploration of the network requires the exploration of networks
# Explore networks to (n, maxDistance - 1)
# As each network is explored, discover the path between the root node and the neighborhood node
# For each path discovered, evaluate the path (e. g. compare with other paths, use the poma, etc.)
# After evaluating the path, serialize it if necessary
# O   O
# |  / neighborhood for (n, 1) consists of all aunexes neighboring n aunex, found 2 steps from the root node
# O O
# |/   neighborhood for (0, 0) consists of all aunexes found at a distance of 1 step from the root node
# O
#tree.neighborhoods[0][0]
#print tree

# for robert, we find william
n5=Node('william')
e4=Edge(n2,n5,0.4)

# now that we have more than one edge, instantiate and serialize a Path object
# the depth is purely relative to the root node, and is retrieved from the number of elements in the Path list property
p1=Path(n1,[e1,e4])

# the max distance hasn't been reached, so explore further
n6=Node('harold')
e5=Edge(n5,n6,0.7)

p2=Path(n1,[e1,e4,e5])

# Exploration cannot take place without structures for storing data detailing Neighborhoods

exit()
