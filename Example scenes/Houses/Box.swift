//
//  Box.swift
//  Mercury
//
//  Created by Joshua Knapp on 2/25/16.
//
//

import Foundation

//HgNode subclass that describes a box with no bottom

class Box:HgNode {
    
    
    init(x: Float, y: Float, z: Float) {
        
        
        super.init()
        defer { self.updateVertexBuffer() }
        vertexData = Array(repeating: vertex(), count: 30)
        
        //up face
        vertexData[0].position = ( x / 2,     y / 2,      z / 2)
        vertexData[1].position = ( -x / 2,       y / 2,      z / 2)
        vertexData[2].position = ( -x / 2,      -y / 2,     z / 2)
        vertexData[3].position = vertexData[2].position
        vertexData[4].position = ( x / 2,       -y / 2,     z / 2)
        vertexData[5].position = vertexData[0].position
        
        for i in 0..<6 {
            vertexData[i].normal = (0,0,1)
        }
        
        //south face
        vertexData[6].position = ( x / 2,     -y / 2,      z / 2)
        vertexData[7].position = ( -x / 2,       -y / 2,      z / 2)
        vertexData[8].position = ( -x / 2,      -y / 2,     -z / 2)
        vertexData[9].position = vertexData[8].position
        vertexData[10].position = ( x / 2,       -y / 2,     -z / 2)
        vertexData[11].position = vertexData[6].position
        
        for i in 6..<12 {
            vertexData[i].normal = (0,-1,0)
        }
        
        //north face
        vertexData[12].position = ( -x / 2,     y / 2,      z / 2)
        vertexData[13].position = ( x / 2,       y / 2,      z / 2)
        vertexData[14].position = ( x / 2,      y / 2,     -z / 2)
        vertexData[15].position = vertexData[14].position
        vertexData[16].position = ( -x / 2,       y / 2,     -z / 2)
        vertexData[17].position = vertexData[12].position
        
        for i in 12..<18 {
            vertexData[i].normal = (0,1,0)
        }
        
        //east face
        vertexData[18].position = ( x / 2,     y / 2,      z / 2)
        vertexData[19].position = ( x / 2,      -y / 2,      z / 2)
        vertexData[20].position = ( x / 2,      -y / 2,     -z / 2)
        vertexData[21].position = vertexData[20].position
        vertexData[22].position = ( x / 2,       y / 2,     -z / 2)
        vertexData[23].position = vertexData[18].position
        
        for i in 18..<24 {
            vertexData[i].normal = (1,0,0)
        }
        
        //west face
        vertexData[24].position = ( -x / 2,     -y / 2,      z / 2)
        vertexData[25].position = ( -x / 2,      y / 2,      z / 2)
        vertexData[26].position = ( -x / 2,      y / 2,     -z / 2)
        vertexData[27].position = vertexData[26].position
        vertexData[28].position = ( -x / 2,       -y / 2,     -z / 2)
        vertexData[29].position = vertexData[24].position
        
        for i in 24..<30 {
            vertexData[i].normal = (-1,0,0)
        }
        
        vertexCount = 30
    }

    
}
