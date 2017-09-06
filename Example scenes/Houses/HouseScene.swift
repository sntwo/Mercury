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
import MetalKit


class HouseScene: HgScene {
    
    var roads = Roads()
    var time:Float = 0
    
    
    override func run() {
        print("running main scene")
        
        rotation = float3(1.4 * .pi, 0, 0.5)
        magnification = 1.5

        
        //add a ground plane
        let floor = HgPlaneNode(width: 5280 * 2, length: 5280 * 2)
        floor.diffuseColor = (0.1,0.9,0.1, 1)
        floor.ambientColor = (0.3,0.3,0.3,1)
        //floor.position = float3(0,0,5)
        addChild(floor)
        
        //add some houses
        for i in -5..<5 {
        //for i in 0...0{
            if let house = houseNode(x: 5, y: 5, z: 5) {
            house.position = float3(Float(i * 50), 0, 5)
            addChild(house)
            }
        }
        
        //add a road
        roads.addSegment(float2(5280, 60), p2:float2(-5280, 60))
        roads.addCars()
        addChild(roads)
        
        
        //print(roads)
        
        //makes a flat background
        //skybox.texture = nil
        //skybox.ambientColor = (0.29,0.58,0.22,1);
        
        
        //load a mdl skycube
        let mdltex = MDLSkyCubeTexture(name: nil,
                                       channelEncoding: .uInt8,
            textureDimensions: [Int32(128), Int32(128)],
            turbidity: 0,
            sunElevation: 1,
            upperAtmosphereScattering: 0.5,
            groundAlbedo: 0.8)
        
        mdltex.groundColor = CGColor(red: 1,green: 1,blue: 1,alpha: 1)
        
        let loader = MTKTextureLoader(device: HgRenderer.device)
        
        do {
            let mtltexture = try loader.newTexture(texture:mdltex)
            //print("loaded texture \(name)")
            
            skybox.texture = mtltexture
        } catch let error {
            print("Failed to load texture, error \(error)")
        }
        
        skybox.type = .textured("abc")
        
        //lightPosition = float3(0,0.5,1)
       
    }
    
    /*
    override func updateScene(_ dt: TimeInterval) {
        super.updateScene(dt)
        time += Float(dt)
        //sunPosition = float3(0, sin(time), cos(time))
        //print(time)
    }*/
    
    
}
