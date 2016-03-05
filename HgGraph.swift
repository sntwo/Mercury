//
//  HgGraph.swift
//  Mercury
//
//  Created by Joshua Knapp on 3/4/16.
//
//

import Foundation
import simd

class HgGraphVertex:Hashable{
    
    var position = float2(0,0)
    var neighbors = Set<HgGraphEdge>()
    
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

class HgGraph {
    
    private var canvas = Set<HgGraphVertex>()

    ///create a new vertex
    func addVertex(position:float2) -> HgGraphVertex{
        let newVertex = HgGraphVertex(position: position)
        canvas.insert(newVertex)
        return newVertex
    }
    
}