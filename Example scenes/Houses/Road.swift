//
//  Road.swift
//  mercury
//
//  Created by Joshua Knapp on 11/14/15.
//  Copyright © 2015 Joshua Knapp. All rights reserved.
//

import Foundation
import simd
import Metal

private let carColors:[float4] = [float4(0.6, 0.9, 0.2, 1.0), float4(0.1, 0.3, 0.9, 1.0), float4(0.2, 0.2, 0.9, 1.0), float4(0.9, 0.1, 0.05, 1.0)]

class Car:HgNode {
    
    var path:[HgGraphVertex] = []
    var pathIndex = 0
    var acceleration:Float = 4 / 60 / 4
    var speed:Float = 0
    var maxSpeed:Float = 1
    var heading = float2(0,0)
    
    static var classtexture:MTLTexture? = {
        return HgRenderer.loadTexture("Car")
    }()
    
    override var texture:MTLTexture? { get {
        return Car.classtexture
    } set {}}
    
    static var defaultVertices:[vertex] = { 
        let carproto = HgOBJNode(name:"Car1")!
        return carproto.vertexData
    }()
    
    weak var currentSegment:RoadSegment!
    
    init?(startNode:HgGraphVertex, endNode:HgGraphVertex) {
        
        super.init()
        type = .textured("Car")
        rotation = float3(0, .pi / 2 , .pi / 2) //empirically set
        path = [startNode, endNode]
        let i = random(0, high: carColors.count - 1)
        let color = carColors[i]
        vertexData = Car.defaultVertices
        vertexCount = vertexData.count
        print("vertices: \(vertexCount)")
        for i in 0..<vertexData.count {
            vertexData[i].ambientColor = (color.x, color.y, color.z, color.w)
            vertexData[i].diffuseColor = (color.x, color.y, color.z, color.w)
        }
        
        scale = float3(2,2,2) //empirically set
        //rotation = float3(.pi / 2, .pi , -.pi / 2) //empirically set
        
        let light = HgLightNode(radius: 100)
        light.position = float3(-5,0,0)
        addLight(light)
        
        let chance = random(0, high: 10)
        if chance < 1 {
            light.color = float3(0.5,0.5,1) //slim chance of annoying LED lights
        }
        
        updateVertexBuffer()
        
        position = float3(Float(startNode.position.x), Float(startNode.position.y), 5)
        updatePosition()
        
        if let seg = Roads.segment(fromNode:path[0], toNode:path[1]){
            currentSegment = seg
            seg.addCar(self)
        }
        else {
            //print("stuck car!")
            //currentSegment.removeCar(self)
        }
        
    }

    func roadUpdate(_ dt: TimeInterval) {
        
        guard pathIndex < path.count - 1 else {
            if let seg = currentSegment {
                seg.removeCar(self)
                parent!.removeChild(self)
            }
            return
        }
        
        //find distance from the car to its target node
        let dist = distance(path[pathIndex + 1].position, float2(position.x, position.y))
        //print("dist is \(dist)")
        if dist < 6 {
            pathIndex += 1
            updatePosition()
        }
        else {
            updateSpeed(dist)
            position.x += heading.x
            position.y += heading.y
        }
        
        
       // print("car position is \(position)")
        super.updateNode(dt)
    }
    
    func updateSpeed(_ distance:Float) {
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
        
        /*
        if let curSeg = currentSegment {
            curSeg.removeCar(self)
        }
        
        if let seg = Roads.segment(fromNode:path[pathIndex], toNode: path[pathIndex + 1]){
            currentSegment = seg
            seg.addCar(self)
        }
        else {
            print("could not find segment")
            recalculatePath()
        }*/
        
        let dv = (path[pathIndex + 1].position - path[pathIndex].position)
        rotation.z = atan2f(dv.y, dv.x)
        let newheading = float2(cosf(rotation.z) * speed, sinf(rotation.z) * speed)
        heading = newheading
        let offset = float2(cos(rotation.z - .pi / 2) * 3.5, sin(rotation.z - .pi / 2 ) * 3.5) //put in right lane
        position.x = path[pathIndex].position.x + offset.x
        position.y = path[pathIndex].position.y + offset.y

    }
    
    func recalculatePath(){
        
        do {
            path = try Roads.graph.dijkstra(from: path[pathIndex], to: path[path.count-1])
        } catch {
            print("could not find path to node")
        }
        
        print("paths has \(path.count) objects")
        pathIndex = 0
        
        if let seg = Roads.segment(fromNode:path[0], toNode:path[1]){
            currentSegment = seg
            seg.addCar(self)
        }
        else {
            print("stuck car!")
        }
    }
}

class Roads:HgNode, CustomStringConvertible{

    static var graph = HgGraph()
    static var segments = [RoadSegment]()
    
    var myVertexCount = 0
    
    var description: String {
        return "Nodes: \(Roads.graph.canvas.count)     Segments: \(Roads.segments.count)     Vertices: \(myVertexCount)"
    }
    
    override var vertexCount: Int {
        get {
            
            return myVertexCount
            
        }
        set { }
    }
    
    func addSegment(_ p1:float2, p2:float2){
        let newSegments = Roads.graph.addConnection(from: p1, to: p2)
        for s in newSegments {
            let r = RoadSegment(edge: s)
            r.roads = self
            Roads.segments.append(r)
        }
        if let s = Roads.segments.last {
            
            //print(s)
            tesselateSegment(s)
        } else {
            print("could not get segment")
        }
        
        //need to add vertices
    }
    
    func addCars(frequency:Int = 100){
        if let s1 = Roads.segments.first {
            let n1 = s1.edge.fromNeighbor
            let n2 = s1.edge.toNeighbor
            s1.destinations += [n2]
            s1.destinations += [n1]
            s1.carGenerationRate = frequency
            //s2.carGenerationRate = frequency
        }
    }
    
    /*
    func removeSegment(seg:RoadSegment, twoway:Bool = true) {
        
        //print("removing segment from \(seg.node1.position) to \(seg.node2.position)")
        
        let count = Roads.segments.count
        for (index, element) in Roads.segments.enumerate(){
            if element === seg {
            
                Roads.segments.removeAtIndex(index)
               
                
                let vc = seg.verticeCount
                vertexData.removeRange(seg.verticeStartIndex..<(seg.verticeStartIndex + seg.verticeCount))
                myVertexCount -= seg.verticeCount
    
                for i in index...count {
                        Roads.segments[i].verticeStartIndex -= vc
                }
                
                return
            }
        }
        print("failed to remove segment")
    }
    */
    
    override func updateNode(_ dt: TimeInterval) {
        super.updateNode(dt)
        for seg in Roads.segments {
            seg.roadUpdate(dt)  //why the !?
        }
    }
    
    //takes a roadSegment and turns it into vertices in the road node
    func tesselateSegment(_ seg:RoadSegment, width:Float = 64){
        
        let line = HgLine(p0:seg.edge.fromNeighbor.position, p1:seg.edge.toNeighbor.position)
        let triangles = line.tesselate(width)
        
        let count = triangles.count
        var newdata = Array(repeating: vertex(), count: count)
        
        
        for (index, point) in triangles.enumerated() {
            newdata[index].position.x = point.x
            newdata[index].position.y = point.y
            newdata[index].position.z = 1
            newdata[index].normal = (0,0,1)
            newdata[index].ambientColor = (0.35,0.35,0.35,1.0)
            newdata[index].diffuseColor = (0.35,0.35,0.35,1.0)
        }
        
        /*
        //some temp coloring to help picture what is going on with the triangles
        for var i = 0; i < 6; i++ {
            newdata[i].Color = (0,0,0,1)
        }
        for var i = count - 6; i < count; i++ {
            newdata[i].Color = (0,0,0,1)
        }*/
        
        
        seg.verticeStartIndex = vertexData.count
        vertexData.append(contentsOf: newdata)
        myVertexCount += count
        seg.verticeCount += count
        
    }
    
    ///searches graph for segment that 
    static func segment(fromNode n1:HgGraphVertex, toNode n2:HgGraphVertex) -> RoadSegment? {
        for segment in segments {
            if n1 == segment.edge.fromNeighbor && n2 == segment.edge.toNeighbor {
                return segment
            }
        }
        return nil
    }
    
    /*
    static func segmentForNode(n1:HgGraphVertex, inout i:Int) -> RoadSegment? {
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
    */
    
    override func rebuffer() {
        super.rebuffer()
        var c = 0
        for s in Roads.segments {
            c += s.verticeCount
        }
        
        print("road vertice count is \(myVertexCount), cummulative vertice count is \(c), data has \(vertexData.count)")
    }
    
}

class RoadSegment{
    var edge:HgGraphEdge
    weak var roads:Roads?
    
    //var zones = [Zone]()
    
    var verticeCount:Int = 0
    var verticeStartIndex:Int = 0
    
    var carGenerationRate = 0
    var node2CarGenerationRate = 0
    var destinations = [HgGraphVertex]()
    
    var cars = [Car]()
    
    init(edge:HgGraphEdge){
        self.edge = edge
    }
    
    func addCar(_ car:Car){
        cars.append(car)
    }
    
    func removeCar(_ car:Car){
        for (index,element) in cars.enumerated() {
            if car === element {
                if cars.remove(at: index) === car {
                    
                }
                else {
                    print("removed wrong car!!")
                }
                break
            }
        }
    }
    
    func roadUpdate(_ dt:TimeInterval){
        //print("cars: \(cars.count)")
        //print("road update, cg is \(carGenerationRate)")
        if carGenerationRate > 0 {
            let chance = random(0, high: 10000)
            let target = random(0, high: destinations.count - 1)
            if chance < carGenerationRate {
                //print("rolled")
                if let r = roads{
                    let car = Car(startNode: edge.fromNeighbor, endNode: destinations[target])
                    let car2 = Car(startNode: edge.toNeighbor, endNode: destinations[target])
                    //print("about to add a car")
                    r.addChild(car!)
                    r.addChild(car2!)
                }
            }
        }
        
        for car in cars {
            car.roadUpdate(dt)
        }
    }
}
