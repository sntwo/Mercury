//
//  HgGraph.swift
//  Mercury
//
//  Created by Joshua Knapp on 3/4/16.
//
//

import Foundation
import simd

///adopt this protocol to be allow entrance into HgGraph.  Position will be rounded to nearest Int
protocol HgGraphable {
    var position:float2 { get }
}

class HgGraphVertex:Hashable, CustomStringConvertible{
    
    var position = float2(0,0)
    var neighbors = Set<HgGraphEdge>()
    var visited = false
    var path:HgGraphPath?
    
    var description:String { get { return "\(position.x) \(position.y)" } }
    
    init(position:float2){
        self.position = position
    }
    
    @discardableResult
    func addConnection(to destination:HgGraphVertex, twoWay:Bool = true) -> [HgGraphEdge] {
        
        var ret = [HgGraphEdge]()
        let toEdge = HgGraphEdge(from: self, to: destination)
        neighbors.insert(toEdge)
        ret += [toEdge]
        
        if twoWay{
            ret += destination.addConnection(to: self, twoWay: false)
        }
        return ret
    }
    
    func removeConnection(to destination:HgGraphVertex, twoWay:Bool = true) {
        neighbors.remove(HgGraphEdge(from:self, to: destination))
        
        if twoWay{
            destination.removeConnection(to: self, twoWay: false)
        }

    }
    
    ///conforming to Hashable
    var hashValue : Int {
        get {
            //going to round off to integers because we don't want points to really be any closer anyway
            let x = Int(round(position.x))
            let y = Int(round(position.y))
            return "\(x),\(y)".hashValue
        }
    }
}

//conforming HgGraphVertex to Equatable
func ==(lhs: HgGraphVertex, rhs: HgGraphVertex) -> Bool {
    return lhs.hashValue == rhs.hashValue
}


class HgGraphEdge:Hashable {
    
    unowned var fromNeighbor: HgGraphVertex
    unowned var toNeighbor: HgGraphVertex
    var weight: Float
    var vector: float2
    var angle: Float
    
    init(from:HgGraphVertex, to:HgGraphVertex) {
        
        toNeighbor = to
        fromNeighbor = from
        weight = distance_squared(to.position, from.position)
        vector = to.position - from.position
        angle = atan2f(vector.y, vector.x)
        
    }
    
    ///conforming to Hashable
    var hashValue : Int { get { return toNeighbor.hashValue } }

}

//conforming HgGraphEdge to Equatable
func ==(lhs: HgGraphEdge, rhs: HgGraphEdge) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

enum djError:Error {
    case notFound
    case unknown
}


///maintains a Set of HgGraphVertex(s)
class HgGraph {
    
    var canvas = Set<HgGraphVertex>()

    ///create a new vertex
    func addVertex(_ object:HgGraphable) -> HgGraphVertex{
        let newVertex = HgGraphVertex(position: object.position)
        canvas.insert(newVertex)
        return newVertex
    }
    
    /// Searches the existing within distance of p1 and p2 and adds a connection if found.  If points are not found, new points are created.  If a new potential point is within distance of an existing connection line, the new point is moved to be on that line.
    /// - parameter distance:  Function will not create a new node less than this distance to an existing node
    /// - parameter p1, p2: 2D points to add the new connection between
    func addConnection(from p1:float2, to p2:float2, twoWay:Bool = true, distance:Float = 16) -> [HgGraphEdge] {
        
        var node1:HgGraphVertex?
        var node2:HgGraphVertex?
        
        //need mutable values
        var point1 = p1
        var point2 = p2
        
        //look for matching nodes
        if let n1 = nodeNearPoint(p1, distance: distance) {
            node1 = n1
        } else {
            if let seg = snapToConnection(&point1, distance: distance){
                
                node1 = HgGraphVertex(position: point1)
                node1!.addConnection(to: seg.toNeighbor)
                node1!.addConnection(to: seg.fromNeighbor)
                
                seg.toNeighbor.removeConnection(to: seg.fromNeighbor)
    
                canvas.insert(node1!)
            }
        }
        
        if let n2 = nodeNearPoint(p2, distance: distance) {
            node2 = n2
        } else {
            if let seg = snapToConnection(&point2, distance: distance){
                
                node2 = HgGraphVertex(position: point2)
                node2!.addConnection(to: seg.toNeighbor)
                node2!.addConnection(to: seg.fromNeighbor)
                
                seg.toNeighbor.removeConnection(to: seg.fromNeighbor)
                
                canvas.insert(node2!)
            }
        }
    
        //no points near existing points or on connections, so create new one(s)
        if let _ = node1 {
            } else {
            
            node1 = HgGraphVertex(position: p1)
            canvas.insert(node1!)
        }
        if let _ = node2 {
            } else {
            node2 = HgGraphVertex(position: p2)
            canvas.insert(node2!)
        }
        
        //need to check for crossing existing edges...
    
        return node2!.addConnection(to: node1!)
        
    }
    
    ///find Dijkstra's shortest path - reference https://en.wikipedia.org/wiki/Dijkstra%27s_algorithm
    func dijkstra(from: HgGraphVertex, to: HgGraphVertex) throws -> [HgGraphVertex] {
    
        var frontier = Set<HgGraphVertex>()
        for n in canvas {
            n.visited = false
            n.path = nil
        }
        
        let sourcePath = HgGraphPath(node: from)
        sourcePath.distance = 0
        from.path = sourcePath
        
        for edge in from.neighbors {
            let path = HgGraphPath(node: edge.toNeighbor)
            path.distance = edge.weight
            path.previous = sourcePath
            edge.toNeighbor.path = path
            frontier.insert(edge.toNeighbor)
        }
        
        while !frontier.isEmpty {
            for node in frontier {
                for edge in node.neighbors {
                    let dist = edge.weight + node.path!.distance
                    if let p = edge.toNeighbor.path {
                        if p.distance > dist {
                            let newPath = HgGraphPath(node: edge.toNeighbor)
                            newPath.distance = dist
                            newPath.previous = node.path!
                            edge.toNeighbor.path = newPath
                        }
                    } else {
                        let newPath = HgGraphPath(node: edge.toNeighbor)
                        newPath.distance = dist
                        newPath.previous = node.path!
                        edge.toNeighbor.path = newPath
                        frontier.insert(edge.toNeighbor)
                    }
                }
                frontier.remove(node)
            }
        }
        
        if let p = to.path {
            var retVal = [HgGraphVertex]()
            retVal.append(p.node)
            while p.previous != nil {
                retVal.insert(p.previous!.node, at:0)
            }
            return retVal
        } else {
            throw djError.notFound
        }
    }
    
    ///returns a vertex within distance of p, if it exists
    func nodeNearPoint(_ p:float2, distance:Float = 16) -> HgGraphVertex? {
        for vertex in canvas{
                if distance_squared(p, vertex.position) < distance * distance {
                    //print("found")
                    return vertex
                }
            }
        return nil
    }
    
    ///moves p to on an edge if it is within a certain distance
    func snapToConnection(_ p:inout float2, distance:Float) -> HgGraphEdge? {
        
        //iterate through all the edges in the graph
        for vertex in canvas {
            for connection in vertex.neighbors {
                //print("segment angle is \(segment.angle)")
                let sn1 = connection.toNeighbor
                let sn2 = connection.fromNeighbor
                let tp = sn1.position
                let dp = sn2.position
                let rotmat = float4x4(ZRotation: -connection.angle)
                let p1 = rotmat * float4(p.x,p.y,1,0)
                let n1 = rotmat * float4(tp.x,tp.y, 1, 0)
                let n2 = rotmat * float4(dp.x, dp.y, 1, 0)
            
                //print("p1 is \(p1) n1 is \(n1) n2 is \(n2)")
                if n1.x...n2.x ~= p1.x && fabs(p1.y - n1.y) < distance {
                //found segment
                
                    let revrotmat = float4x4(ZRotation: connection.angle)
                    let p2 = revrotmat * float4(p1.x, n1.y, 0, 1)
                    p.x = p2.x
                    p.y = p2.y
                
                    return connection
                }
            }
        }
        return nil
    }
}

//conforming HgGraphEdge to Equatable
func ==(lhs: HgGraphPath, rhs: HgGraphPath) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

class HgGraphPath:Hashable {
    
    ///the distance of the path through nodes
    var distance: Float = .greatestFiniteMagnitude
    var node:HgGraphVertex
    var previous: HgGraphPath?
    
    init(node:HgGraphVertex){
        self.node = node
    }

    ///conforming to Hashable
    var hashValue : Int {
        get {
            return "\(String(describing: previous?.hashValue))".hashValue
        }
    }
}

