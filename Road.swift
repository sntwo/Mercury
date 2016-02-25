//
//  Road.swift
//  mercury
//
//  Created by Joshua Knapp on 11/14/15.
//  Copyright © 2015 Joshua Knapp. All rights reserved.
//

import Foundation
import GameplayKit
import simd

private let carColors:[float4] = [float4(0.6, 0.9, 0.2, 1.0), float4(0.1, 0.3, 0.9, 1.0), float4(0.2, 0.2, 0.9, 1.0), float4(0.9, 0.1, 0.05, 1.0)]

class Car:Box {
    
    var path:[GKGraphNode2D]
    var pathIndex = 0
    var acceleration:Float = 4 / 60 / 4
    var speed:Float = 0
    var maxSpeed:Float = 4
    var heading = float2(0,0)
    
    weak var currentSegment:RoadSegment!
    
    init(startNode:GKGraphNode2D, endNode:GKGraphNode2D) {
        
        
        path = Roads.graph.findPathFromNode(startNode, toNode: endNode) as! [GKGraphNode2D]
        if path.isEmpty {
            print("could not find path!")
        } else {
            print("made path with \(path.count) nodes")
        }
    
        super.init(x: 10, y: 5, z: 6)
        
        let i = random(0, high: carColors.count - 1)
        let color = carColors[i]
        for i in 0..<vertexData.count {
            vertexData[i].ambientColor = (color.x, color.y, color.z, color.w)
            vertexData[i].diffuseColor = (color.x, color.y, color.z, color.w)
        }
        
        let light = HgLightNode(radius: 100)
        light.position = float3(5,0,0)
        addLight(light)
        
        updateVertexBuffer()
        position = float3(startNode.position.x, startNode.position.y, 5)
        updatePosition()

    }
    
    
    
    func roadUpdate(dt: NSTimeInterval) {
        
        guard pathIndex < path.count - 1 else {
            if let seg = currentSegment {
                seg.removeCar(self)
                parent!.removeChild(self)
            }
            return
        }
        
        let dist = distance(path[pathIndex + 1].position, float2(position.x, position.y))
        
        if dist < 6 {
            pathIndex++
            updatePosition()
        }
        else {
            updateSpeed(dist)
            position.x += heading.x
            position.y += heading.y
        }
        
        //print("car position is \(position)")
        super.updateNode(dt)
    }
    
    func updateSpeed(distance:Float) {
        if distance < 480 {
            speed -= acceleration
            if speed < 1.0 {
                speed = 1.0
            }
        }
        else if speed < maxSpeed {
            speed += acceleration
        }
        heading = float2(cosf(rotation.z) * speed, sinf(rotation.z) * speed)
    }
    
    func updatePosition(){
        
        guard pathIndex < path.count - 1 else { return }
    
        if let curSeg = currentSegment {
            curSeg.removeCar(self)
        }
        
        if let seg = Roads.segmentForNodes(path[pathIndex], n2: path[pathIndex + 1]){
            currentSegment = seg
            seg.addCar(self)
        }
        else {
            recalculatePath()
        }
        
        let dv = (path[pathIndex + 1].position - path[pathIndex].position)
        rotation.z = atan2f(dv.y, dv.x)
        let newheading = float2(cosf(rotation.z) * speed, sinf(rotation.z) * speed)
        heading = newheading
        let offset = float2(cos(rotation.z - Float(M_PI) / 2) * 3.5, sin(rotation.z - Float(M_PI) / 2 ) * 3.5) //put in right lane
        position.x = path[pathIndex].position.x + offset.x
        position.y = path[pathIndex].position.y + offset.y

    }
    
    func recalculatePath(){
        path = Roads.graph.findPathFromNode(path[pathIndex], toNode: path[path.count-1]) as! [GKGraphNode2D]
        if path.isEmpty {
            print("could not find path!")
        } else {
            print("made path with \(path.count) nodes")
        }

        pathIndex = 0
        if let seg = Roads.segmentForNodes(path[pathIndex], n2: path[pathIndex + 1]){
            currentSegment = seg
            seg.addCar(self)
        
        }
        else {
            print("stuck car!")
        }
    }
}

class Roads:HgNode, CustomStringConvertible{
    
    
    
    static var graph = GKGraph()
    static var segments = [RoadSegment]()
    
    var myVertexCount = 0
    
    var description: String {
        return "Nodes: \(Roads.graph.nodes!.count)     Segments: \(Roads.segments.count)     Vertices: \(myVertexCount)"
    }
    
    override var vertexCount: Int {
        get {
            //print("returning \(myVertexCount)")
            return myVertexCount
            
        }
        set { }
    }
    
    func removeSegment(seg:RoadSegment) {
        
        //print("removing segment from \(seg.node1.position) to \(seg.node2.position)")
        
        let count = Roads.segments.count
        for (index, element) in Roads.segments.enumerate(){
            if element === seg {
            
                Roads.segments.removeAtIndex(index)
                for car in seg.forwardCars {
                    car.removeFromGraph()
                }
                for car in seg.backwardCars {
                    car.removeFromGraph()
                }
                
                let vc = seg.verticeCount
                vertexData.removeRange(seg.verticeStartIndex..<(seg.verticeStartIndex + seg.verticeCount))
                myVertexCount -= seg.verticeCount
    
                if index + 1 < count {
                    for var i = index; i < count - 1; i++ {
                        Roads.segments[i].verticeStartIndex -= vc
                    }
                }
                
                return
            }
        }
        print("failed to remove segment")
    }
    
    
    override func updateNode(dt: NSTimeInterval) {
        super.updateNode(dt)
        for seg in Roads.segments {
            seg.roadUpdate(dt)
        }
    }
    
   
    func setDestinations(dests:[Node], forNode:Node, frequency:Int) {
        var i:Int = 0
        if let s = Roads.segmentForNode(forNode, i: &i) {
            if i == 1 {
                s.node1CarGenerationRate = 10
            }
            else if i == 2 {
                s.node2CarGenerationRate = 10
            }
            s.destinations += dests
        }
    }
    
    //add a new segment.  This function needs to check for crossing roads or nodes...
    func addSegment(p1:float2, p2:float2){
        
        //print("addSegment \(p1) \(p2)")
        var node1:Node!
        var node2:Node!
        
        var found1 = false
        var found2 = false
        
        //look for matching nodes
        if let n1 = nodeNearPoint(p1, distance: 16) {
            //print("adding to existing node for 1st point")
            node1 = n1
            found1 = true
        }
        if let n2 = nodeNearPoint(p2, distance: 16) {
            //print("adding to existing node for 2nd point")
            node2 = n2
            found2 = true
        }
        
        if found1 && found2 {
            let roadSegment = RoadSegment(node1: node1, node2: node2, roads:self)
            Roads.segments += [roadSegment]
            tesselateSegment(roadSegment, width: 16)
            return
        }
        
        var P1 = p1
        var P2 = p2
        
        let seg:RoadSegment? = nil
        let seg2:RoadSegment? = nil
        
        //look for points on existing roads
        if !found1 {
            if let seg = snapToRoadSegment(&P1, distance: 16) {
                print("found1")
                node1 = Node(point: P1)
                node1.addConnectionsToNodes([seg.node1, seg.node2], bidirectional: true)
                seg.node1.removeConnectionsToNodes([seg.node2], bidirectional: true)
                removeSegment(seg)
        
                let newSegA = RoadSegment(node1: seg.node1, node2: node1, roads:self)
                newSegA.destinations = seg.destinations
                newSegA.node1CarGenerationRate = seg.node1CarGenerationRate
                //print("added segment from \(seg.node1.position) to \(node1.position)")

                let newSegB = RoadSegment(node1: node1, node2: seg.node2, roads:self)
                newSegB.destinations = seg.destinations
                newSegB.node2CarGenerationRate = seg.node2CarGenerationRate
                //print("added segment from \(node1.position) to \(seg.node2.position)")

                Roads.segments += [newSegA, newSegB]
                tesselateSegment(newSegA, width: 16)
                tesselateSegment(newSegB, width: 16)
                found1 = true
                Roads.graph.addNodes([node1])
                //print("adding to existing segment for 1st point")
            }
        }
        if !found2 {
            if let seg2 = snapToRoadSegment(&P2, distance: 16) {
                print("found2")
                node2 = Node(point:P2)
                node2.addConnectionsToNodes([seg2.node1, seg2.node2], bidirectional: true)
                seg2.node1.removeConnectionsToNodes([seg2.node2], bidirectional: true)
                removeSegment(seg2)
        
                let newSegA = RoadSegment(node1: seg2.node1, node2: node2, roads:self)
                //print("added segment from \(seg2.node1.position) to \(node2.position)")

                let newSegB = RoadSegment(node1: node2, node2: seg2.node2, roads:self)
               // print("added segment from \(node2.position) to \(seg2.node2.position)")

                Roads.segments += [newSegA, newSegB]
                tesselateSegment(newSegA, width: 16)
                tesselateSegment(newSegB, width: 16)
                found2 = true
                Roads.graph.addNodes([node2])
                //print("adding to existing segment for 2nd point")
            }
        }
        
        if seg === seg2 && seg != nil { print("warning: overlaying road segments") }
        
        if found1 {
            //print("found first point")
        } else {
            node1 = Node(point:p1)
            Roads.graph.addNodes([node1])
            //print("creating new node for 1st point at \(p1)")
        }
        if found2 {
            //print("found second point")
        } else {
            node2 = Node(point:p2)
            Roads.graph.addNodes([node2])
            //("creating new node for 2nd Point at \(p2)")
        }
        node2.addConnectionsToNodes([node1], bidirectional: true)
        
        let newSeg = RoadSegment(node1: node1, node2: node2, roads:self)
        Roads.segments += [newSeg]
        tesselateSegment(newSeg, width: 16)
        //print("added segment from \(node1.position) to \(node2.position)")
    }
    
    //takes a roadSegment and turns it into vertices in the road node
    func tesselateSegment(seg:RoadSegment, width:Float){
        
        let triangles = seg.tesselate(width)
        
        let count = triangles.count
        var newdata = Array(count: count, repeatedValue: vertex())
        
        
        for (index, point) in triangles.enumerate() {
            newdata[index].position.x = point.x
            newdata[index].position.y = point.y
            newdata[index].position.z = 1
            newdata[index].normal = (0,0,1)
            newdata[index].ambientColor = (0.35,0.35,0.35,1.0)
            newdata[index].diffuseColor = (0.35,0.35,0.35,1.0)
        }
        
        /*
        //some temp coloring to help picture wtf is going on with the triangles
        for var i = 0; i < 6; i++ {
            newdata[i].Color = (0,0,0,1)
        }
        for var i = count - 6; i < count; i++ {
            newdata[i].Color = (0,0,0,1)
        }*/
        
        seg.verticeStartIndex = vertexData.count
        vertexData.appendContentsOf(newdata)
        myVertexCount += count
        seg.verticeCount += count

    }
    
   
    
    
    ///moves p to on a line segment if it is within a certain distance
    func snapToRoadSegment(inout p:float2, distance:Float) -> RoadSegment? {
        
        for segment in Roads.segments {
            print("segment angle is \(segment.angle)")
            let rotmat = float4x4(ZRotation: -segment.angle)
            let p1 = rotmat * float4(p.x,p.y,1,0)
            let n1 = rotmat * float4(segment.node1.position.x, segment.node1.position.y, 1, 0)
            let n2 = rotmat * float4(segment.node2.position.x, segment.node2.position.y, 1, 0)
        
            print("p1 is \(p1) n1 is \(n1) n2 is \(n2)")
            if n1.x < p1.x && p1.x < n2.x && fabs(p1.y - n1.y) < distance {
                //found segment
                
                let revrotmat = float4x4(ZRotation: segment.angle)
                let p2 = revrotmat * float4(p1.x, n1.y, 0, 1)
                p.x = p2.x
                p.y = p2.y
            
                return segment

            }

        }

        return nil
    }
    
    static func segmentForNodes(n1:GKGraphNode2D, n2:GKGraphNode2D) -> RoadSegment? {
        for segment in segments {
            if segment.node1 === n1 && segment.node2 === n2 || segment.node1 === n2 && segment.node2 == n1 {
                return segment
            }
        }
        return nil
    }
    
    static func segmentForNode(n1:GKGraphNode2D, inout i:Int) -> RoadSegment? {
        for segment in segments {
            if segment.node1 === n1 {
                i = 1
                return segment
            }
            else if segment.node2 === n1 {
                i = 2
                return segment
            }
        }
        print("could not find segment for node!")
        return nil
    }

    
    ///returns a node within distance of p, if it exists
    func nodeNearPoint(p:float2, distance:Float) -> Node? {
        //print("finding node near \(p)")
        if let nodes = Roads.graph.nodes as? [Node] {
            for node in nodes{
                if distance_squared(p, node.position) < distance * distance {
                    print("found")
                    return node
                }
            }
        }
        //print("did not find node near \(p)")
        return nil
    }
    
    override func rebuffer() {
        super.rebuffer()
        var c = 0
        for s in Roads.segments {
            c += s.verticeCount
        }
        
        print("road vertice count is \(myVertexCount), cummulative vertice count is \(c), data has \(vertexData.count)")
    }
    
}

class Node:GKGraphNode2D {
    
}



class RoadSegment:HgLine{
    
    weak var node1:Node!
    weak var node2:Node!
    
    weak var roads:Roads!
    
    //var zones = [Zone]()
    
    var verticeCount:Int = 0
    var verticeStartIndex:Int = 0
    
    var node1CarGenerationRate = 0
    var node2CarGenerationRate = 0
    var destinations = [Node]()
    
    var forwardCars = [Car]()
    var backwardCars = [Car]()
    
    init(node1:Node, node2:Node, roads:Roads){
        self.node1 = node1
        self.node2 = node2
        self.roads = roads
        
        super.init(p0:node1.position, p1:node2.position)
        //chop(10) //take some off each end to give room for curves between segments
    }
    
    func addCar(car:Car){
        if car.path[car.pathIndex] === node1 {
            forwardCars.append(car)
        }
        else {
            backwardCars.append(car)
        }
    }
    
    func removeCar(car:Car){
                
        for (index,element) in forwardCars.enumerate() {
            if car === element {
                if forwardCars.removeAtIndex(index) === car {
                    
                }
                else {
                    print("removed wrong car!!")
                }
                break
            }
        }
        for (index,element) in backwardCars.enumerate() {
            if car === element {
                if backwardCars.removeAtIndex(index)  === car {
                    
                }
                else {
                    print("removed wrong car!!")
                }

                break
            }
        }
    }
    
    func roadUpdate(dt:NSTimeInterval){
        
        if node1CarGenerationRate > 0 || node2CarGenerationRate > 0 {
            let chance = random(0, high: 10000)
            let target = random(0, high: destinations.count - 1)
            if chance < node1CarGenerationRate {
                let car = Car(startNode: node1, endNode: destinations[target])
                roads.addChild(car)
            }
            else if chance < node2CarGenerationRate {
                let car = Car(startNode: node2, endNode: destinations[target])
                roads.addChild(car)
            }
        }
        
        for car in forwardCars {
            car.roadUpdate(dt)
        }
        for car in backwardCars {
            car.roadUpdate(dt)
        }
    }
}