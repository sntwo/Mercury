//
//  CubeScene.swift
//  IOSMercury
//
//  Created by Joshua Knapp on 7/8/17.
//

import Foundation
import simd

class CubeScene: HgScene {

    override func run(){
        
        position = float3(0,0,500)
        //rotation = float3(.pi, 0, 0)
        //magnification = 0.1
        let box = Box(x:100, y:100, z:100)
        addChild(box)
        
        
    }
}
