//
//  HgGraph.swift
//  Mercury
//
//  Created by Joshua Knapp on 3/4/16.
//
//

import Foundation
import simd

class HgGraphVertex:Hashable, CustomStringConvertible{
    
    var position = float2(0,0)
    var neighbors = Set<HgGraphEdge>()
    var visited = false
    var path:HgGraphPath?
    
    var description:String { get { return "\(position.x) \(position.y)" } }
    
    init(position:float2){
        self.position = position
    }
    
    func addEdge(to destination:HgGraphVertex, twoWay:Bool = true) {
        
        neighbors.insert(HgGraphEdge(from: self, to: destination))
        
        if twoWay{
            destination.addEdge(to: self, twoWay: false)
        }
    }
    
    ///conforming to Hashable
    var hashValue : Int {
        get {
            return "\(position.x),\(position.y)".hashValue
        }
    }


}

//conforming HgGraphVertex to Equatable
func ==(lhs: HgGraphVertex, rhs: HgGraphVertex) -> Bool {
    return lhs.hashValue == rhs.hashValue
}


struct HgGraphEdge: Hashable {
    
    unowned var fromNeighbor: HgGraphVertex
    unowned var toNeighbor: HgGraphVertex
    var weight: Float
    
    init(from:HgGraphVertex, to:HgGraphVertex) {
        
        toNeighbor = to
        fromNeighbor = from
        weight = distance(from.position, to.position)
    }
    
    ///conforming to Hashable
    var hashValue : Int { get { return toNeighbor.hashValue } }
    
}

//conforming HgGraphEdge to Equatable
func ==(lhs: HgGraphEdge, rhs: HgGraphEdge) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

enum djError:ErrorType {
    case notFound
    case unknown
}

class HgGraph {
    
    private var canvas = Set<HgGraphVertex>()

    ///create a new vertex
    func addVertex(position:float2) -> HgGraphVertex{
        let newVertex = HgGraphVertex(position: position)
        canvas.insert(newVertex)
        return newVertex
    }
    
    ///find Dijkstra's shortest path
    //reference https://en.wikipedia.org/wiki/Dijkstra%27s_algorithm
    func dijkstra(from: HgGraphVertex, to: HgGraphVertex) throws -> HgGraphPath {
    
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
            return p
        } else {
            throw djError.notFound
        }
    }
    
}

//conforming HgGraphEdge to Equatable
func ==(lhs: HgGraphPath, rhs: HgGraphPath) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

class HgGraphPath:Hashable {
    
    ///the distance of the path through nodes
    var distance: Float = FLT_MAX
    var node:HgGraphVertex
    var previous: HgGraphPath?
    
    init(node:HgGraphVertex){
        self.node = node
    }

    ///conforming to Hashable
    var hashValue : Int {
        get {
            return "\(previous?.hashValue)".hashValue
        }
    }
    
    
}