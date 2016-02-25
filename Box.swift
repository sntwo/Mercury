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
        defer { self.updateVertexBuffer() }
        
        super.init()
        
        vertexData = Array(count: 30, repeatedValue: vertex())
        
        //right wound
        //describe faces indices thusly:
        //   + 0.......1,4
        //     .      / .
        //     .     /  .
        //     .    /   .
        //     .  /     .
        //     2,3......5  +
        //
        //      axes: up(y axis), right(x axis), and toward viewer(z axis) are positive
        
        
        //let rand = random(0, high: housediffuseColors.count - 1)
        //let h = housediffuseColors[rand]
        
        //up face
        vertexData[1].position = ( x / 2,     y / 2,      z / 2)
        vertexData[0].position = ( -x / 2,       y / 2,      z / 2)
        vertexData[2].position = ( -x / 2,      -y / 2,     z / 2)
        vertexData[3].position = vertexData[2].position
        vertexData[5].position = ( x / 2,       -y / 2,     z / 2)
        vertexData[4].position = vertexData[1].position
        
        for i in 0..<6 {
            vertexData[i].normal = (0,0,1)
        }
        
        //south face
        vertexData[7].position = ( x / 2,     -y / 2,      z / 2)
        vertexData[6].position = ( -x / 2,       -y / 2,      z / 2)
        vertexData[8].position = ( -x / 2,      -y / 2,     -z / 2)
        vertexData[9].position = vertexData[8].position
        vertexData[11].position = ( x / 2,       -y / 2,     -z / 2)
        vertexData[10].position = vertexData[7].position
        
        for i in 6..<12 {
            vertexData[i].normal = (0,-1,0)
        }
        
        //north face
        vertexData[13].position = ( -x / 2,     y / 2,      z / 2)
        vertexData[12].position = ( x / 2,       y / 2,      z / 2)
        vertexData[14].position = ( x / 2,      y / 2,     -z / 2)
        vertexData[15].position = vertexData[14].position
        vertexData[17].position = ( -x / 2,       y / 2,     -z / 2)
        vertexData[16].position = vertexData[13].position
        
        for i in 12..<18 {
            vertexData[i].normal = (0,1,0)
        }
        
        //east face
        vertexData[19].position = ( x / 2,     y / 2,      z / 2)
        vertexData[18].position = ( x / 2,      -y / 2,      z / 2)
        vertexData[20].position = ( x / 2,      -y / 2,     -z / 2)
        vertexData[21].position = vertexData[20].position
        vertexData[23].position = ( x / 2,       y / 2,     -z / 2)
        vertexData[22].position = vertexData[19].position
        
        for i in 18..<24 {
            vertexData[i].normal = (1,0,0)
        }
        
        //west face
        vertexData[25].position = ( -x / 2,     -y / 2,      z / 2)
        vertexData[24].position = ( -x / 2,      y / 2,      z / 2)
        vertexData[26].position = ( -x / 2,      y / 2,     -z / 2)
        vertexData[27].position = vertexData[26].position
        vertexData[29].position = ( -x / 2,       -y / 2,     -z / 2)
        vertexData[28].position = vertexData[25].position
        
        for i in 24..<30 {
            vertexData[i].normal = (-1,0,0)
        }
        
        /*
        for i in 0..<30 {
            /*
            vertexData[i].diffuseColor.r = h[0]
            vertexData[i].diffuseColor.g = h[1]
            vertexData[i].diffuseColor.b = h[2]
            vertexData[i].diffuseColor.a = h[3]
            vertexData[i].ambientColor.r = h[0]
            vertexData[i].ambientColor.g = h[1]
            vertexData[i].ambientColor.b = h[2]
            vertexData[i].ambientColor.a = h[3]
            */
        }*/
        
        vertexCount = 30
    }

    
}