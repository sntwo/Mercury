//
//  House.swift
//  mercury
//
//  Created by Joshua Knapp on 11/14/15.
//  Copyright © 2015 Joshua Knapp. All rights reserved.
//

import Foundation
import simd

class houseNode:HgOBJNode{
    
    init?(x: Float, y: Float, z: Float) {
        let idx = random(1, high: 6)
        super.init(name:"House" + String(idx))
        type = .textured("House")
        scale = float3(x,y,z) //empirically set
        rotation = float3(.pi / 2, .pi , 0) //empirically set
    }
    
}
