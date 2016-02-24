//
//  HgPlaneNode.swift
//  Mercury
//
//  Created by Joshua Knapp on 12/20/15.
//
//

import Foundation
import simd

class HgPlaneNode:HgNode {
    
    let width:Float
    let length:Float
    
    init(width:Float, length:Float) {
        self.width = width
        self.length = length
       
        let x = width
        let y = length
        
        super.init()
        
        //right wound...
        vertexData = Array(count: 6, repeatedValue: vertex())
        
        vertexData[0].position = ( -x / 2,     y / 2,      0)
        vertexData[1].position = ( x / 2,       y / 2,      0)
        vertexData[2].position = ( x / 2,      -y / 2,     0)
        vertexData[3].position = vertexData[2].position
        vertexData[4].position = ( -x / 2,       -y / 2,     0)
        vertexData[5].position = vertexData[0].position
        
        vertexCount = 6
        
        self.updateVertexBuffer()
    }
}