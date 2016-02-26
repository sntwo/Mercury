//
//  MainScene.swift
//  Mercury
//
//  Created by Joshua Knapp on 12/19/15.
//
//

import Foundation
import simd
import ModelIO


class MainScene: HgScene {
    
     var roads = Roads()
    
    override func run() {
        print("running main scene")
        rotation = float3(Float(M_PI) / 2.5, 0, 0)
        
        //add a ground plane
        let floor = HgPlaneNode(width: 5280 * 2, length: 5280 * 2)
        addChild(floor)
        
        //add some houses
        for i in -5..<5 {
            let house = houseNode(x: 30, y: 20, z: 10)
            house.position = float3(Float(i * 50), 0, 5)
            addChild(house)
        }
        
        //add a road 
        /*
        let road = Box(x: 1000, y: 18, z: 1)
        road.position = float3(0, 60, 1)
        addChild(road)
        */
        
        
        roads.addSegment(float2(5280, 60), p2:float2(-5280, 60))
        //roads.addSegment(float2(0, 800), p2: float2(0,60))
        //roads.addSegment(float2(-5280, 5280), p2:float2(0,800))
       
        //let t1 = roads.nodeNearPoint(float2(-5280, 5280), distance: 50)
        if let t2 = roads.nodeNearPoint(float2(-5280, 60), distance: 50),
            t3 = roads.nodeNearPoint(float2(5280, 60), distance: 50) {
        print("added destinations")
                roads.setDestinations([t2], forNode:t3, frequency:100)
                roads.setDestinations([t3], forNode:t2, frequency:100)
        }
        //roads.setDestinations([t1!, t2!], forNode:t3!, frequency:10)

        addChild(roads)
    
        print(roads)


        /*
        let light = HgLightNode(radius: 100)
        light.position = float3(0,0,25)
        addLight(light)
        */
        
        //skybox.position = float3(0,0,0)
        
        
        //makes a flat yellow background
        skybox.texture = nil
        skybox.ambientColor = (0.29,0.58,0.22,1);
        
        /*
        let mdltex = MDLSkyCubeTexture(name: nil,
            channelEncoding: .UInt8,
            textureDimensions: [Int32(128), Int32(128)],
            turbidity: 0,
            sunElevation: 1,
            upperAtmosphereScattering: 0.5,
            groundAlbedo: 0.2)
        mdltex.groundColor = CGColorCreateGenericRGB(0,0.0,0,1)
        skybox.texture = HgSkyboxNode.loadCubeTextureWithMDLTexture(mdltex)
        skybox.scale = float3(10,10,10)
       */
        /*
        let ts = HgSkyboxNode(size: 100)
        ts.position = float3(50,100,200)
        addChild(ts)
        */
    }
    
}