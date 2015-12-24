//
//  MainScene.swift
//  Mercury
//
//  Created by Joshua Knapp on 12/19/15.
//
//

import Foundation
import simd

class MainScene: HgScene {
    
    override func run() {
        print("running main scene")
        rotation = float3(Float(M_PI) / 2.5, 0, 0)
        
        let topNode = HgPlaneNode(width: 1000,length: 1000)
        topNode.position = float3(0,0,1)
        addChild(topNode)
    
        
        let light = HgLightNode(radius: 100)
        light.position = float3(0,0,25)
        addLight(light)
    }
}