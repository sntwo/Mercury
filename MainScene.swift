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
    
    override func run() {
        print("running main scene")
        rotation = float3(Float(M_PI) / 2.5, 0, 0)
        
        
        let topNode = HgPlaneNode(width: 1000,length: 1000)
        topNode.position = float3(0,0,1)
        //addChild(topNode)
        
        for i in -5..<5 {
            let house = houseNode(x: 30, y: 20, z: 10)
            house.position = float3(Float(i * 50), 0, 1)
            addChild(house)
        }
    
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