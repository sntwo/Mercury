//
//  House.swift
//  mercury
//
//  Created by Joshua Knapp on 11/14/15.
//  Copyright © 2015 Joshua Knapp. All rights reserved.
//

import Foundation
import simd

private var housediffuseColors =  [float4(87/255, 184/255, 171/255, 1), float4(21/255,50/255,67/255,1), float4(40/255,75/255,99/255,1), float4(157/255,161/255,213/255,1), float4(238/255,240/255,235/255,1)]

class houseNode:HgNode{
    
    init(x: Float, y: Float, z: Float) {
        
    
        super.init()
        defer { self.updateVertexBuffer() }
        
        vertexData = Array(repeating: vertex(), count: 84)
        
        //describe faces indices thusly: left wound
        //   + 1.......0,5
        //     .      / .
        //     .     /  .
        //     .    /   .
        //     .  /     .
        //     2,3......4  +
        //
        //      axes: up(y axis), right(x axis), and toward viewer(z axis) are positive
        
        let rand = random(0, high: housediffuseColors.count - 1)
        let h = housediffuseColors[rand]
        
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
        
        for i in 0..<30 {
            vertexData[i].diffuseColor.r = h[0]
            vertexData[i].diffuseColor.g = h[1]
            vertexData[i].diffuseColor.b = h[2]
            vertexData[i].diffuseColor.a = h[3]
            vertexData[i].ambientColor.r = h[0]
            vertexData[i].ambientColor.g = h[1]
            vertexData[i].ambientColor.b = h[2]
            vertexData[i].ambientColor.a = h[3]
        }
        //diffuseColor = h//float4(102/255, 164/255,229/255,1)
        
        //east roof
        vertexData[30].position = ( x / 2 + 2,     y / 2 + 2,      z / 2 - 2 * 5 / 12 + 0.01)
        vertexData[31].position = ( 0,      y / 2 + 2,      z / 2 + x / 2 * 5 / 12 + 0.01)
        vertexData[32].position = ( 0,      -y / 2 - 2,     z / 2 + x / 2 * 5 / 12 + 0.01)
        vertexData[33].position = vertexData[32].position
        vertexData[34].position = ( x / 2 + 2,       -y / 2 - 2,     z / 2 - 2 * 5 / 12 + 0.01)
        vertexData[35].position = vertexData[30].position
        
        
        //The roof slope is 5/12, so the normal will be 12/5
        let n = normalize(float3(12, 0, 5))
        for i in 30..<36 {
            vertexData[i].normal.x = n.x
            vertexData[i].normal.y = n.y
            vertexData[i].normal.z = n.z
        }
        
        
        //west roof
        vertexData[36].position = ( 0,     y / 2 + 2,      z / 2 + x / 2 * 5 / 12 + 0.01)
        vertexData[37].position = ( -x / 2 - 2,       y / 2 + 2,      z / 2 - 2 * 5 / 12 + 0.01)
        vertexData[38].position = ( -x / 2 - 2,      -y / 2 - 2,     z / 2 - 2 * 5 / 12 + 0.01)
        vertexData[39].position = vertexData[38].position
        vertexData[40].position = ( 0,       -y / 2 - 2,     z / 2 + x / 2 * 5 / 12 + 0.01)
        vertexData[41].position = vertexData[36].position
        
        let n2 = normalize(float3(-12, 0, 5))
        for i in 36..<42 {
            vertexData[i].normal.x = n2.x
            vertexData[i].normal.y = n2.y
            vertexData[i].normal.z = n2.z
        }
        
        let c = float4(190/255,84/255,64/255,1)
        for i in 30..<42 {
            vertexData[i].diffuseColor.r = c[0]
            vertexData[i].diffuseColor.g = c[1]
            vertexData[i].diffuseColor.b = c[2]
            vertexData[i].diffuseColor.a = c[3]
            
            vertexData[i].ambientColor.r = c[0]
            vertexData[i].ambientColor.g = c[1]
            vertexData[i].ambientColor.b = c[2]
            vertexData[i].ambientColor.a = c[3]
        }
        
        //north triangle
        vertexData[42].position = (-x / 2, y / 2, z / 2)
        vertexData[43].position = (0, y / 2, z / 2 + x / 2 * 5 / 12)
        vertexData[44].position = (x / 2, y / 2, z / 2)
        vertexData[42].normal = (0, 1, 0)
        vertexData[43].normal = (0, 1, 0)
        vertexData[44].normal = (0, 1, 0)
        
        //south triangle
        vertexData[45].position = (x / 2, -y / 2, z / 2)
        vertexData[46].position = (0, -y / 2, z / 2 + x / 2 * 5 / 12)
        vertexData[47].position = (-x / 2, -y / 2, z / 2)
        vertexData[45].normal = (0, -1, 0)
        vertexData[46].normal = (0, -1, 0)
        vertexData[47].normal = (0, -1, 0)
        
        for i in 42..<48 {
            vertexData[i].diffuseColor.r = h[0]
            vertexData[i].diffuseColor.g = h[1]
            vertexData[i].diffuseColor.b = h[2]
            vertexData[i].diffuseColor.a = h[3]
            vertexData[i].ambientColor.r = h[0]
            vertexData[i].ambientColor.g = h[1]
            vertexData[i].ambientColor.b = h[2]
            vertexData[i].ambientColor.a = h[3]
        }
        
        //east coping
        vertexData[48].position = ( x / 2 + 2,     y / 2 + 2,      z / 2 - 2 * 5 / 12  + 0.01)
        vertexData[49].position = (  x / 2 + 2,     -y / 2 - 2,      z / 2 - 2 * 5 / 12 + 0.01)
        vertexData[50].position = (  x / 2 + 2,      -y / 2 - 2,     z / 2 - 2 * 5 / 12 - 1 + 0.01)
        vertexData[51].position = vertexData[50].position
        vertexData[52].position = ( x / 2 + 2,       y / 2 + 2,     z / 2 - 2 * 5 / 12 - 1 + 0.01)
        vertexData[53].position = vertexData[48].position
        
        for i in 48..<54 {
            vertexData[i].normal.x = 1
            vertexData[i].normal.y = 0
            vertexData[i].normal.z = 0
            
            vertexData[i].diffuseColor.r = c[0]
            vertexData[i].diffuseColor.g = c[1]
            vertexData[i].diffuseColor.b = c[2]
            vertexData[i].diffuseColor.a = c[3]
            vertexData[i].ambientColor.r = c[0]
            vertexData[i].ambientColor.g = c[1]
            vertexData[i].ambientColor.b = c[2]
            vertexData[i].ambientColor.a = c[3]
        }
        
        //west coping
        vertexData[54].position = ( -x / 2 - 2,     -y / 2 - 2,      z / 2 - 2 * 5 / 12 + 0.01)
        vertexData[55].position = (  -x / 2 - 2,     y / 2 + 2,      z / 2 - 2 * 5 / 12 + 0.01)
        vertexData[56].position = (  -x / 2 - 2,      y / 2 + 2,     z / 2 - 2 * 5 / 12 - 1 + 0.01)
        vertexData[57].position = vertexData[56].position
        vertexData[58].position = ( -x / 2 - 2,       -y / 2 - 2,     z / 2 - 2 * 5 / 12 - 1 + 0.01)
        vertexData[59].position = vertexData[54].position
        
        for i in 54..<60 {
            vertexData[i].normal.x = -1
            vertexData[i].normal.y = 0
            vertexData[i].normal.z = 0
            
            vertexData[i].diffuseColor.r = c[0]
            vertexData[i].diffuseColor.g = c[1]
            vertexData[i].diffuseColor.b = c[2]
            vertexData[i].diffuseColor.a = c[3]
            vertexData[i].ambientColor.r = c[0]
            vertexData[i].ambientColor.g = c[1]
            vertexData[i].ambientColor.b = c[2]
            vertexData[i].ambientColor.a = c[3]

        }
        
        //southeast coping
        vertexData[60].position = ( x / 2 + 2,     -y / 2 - 2,      z / 2 - 2 * 5 / 12  + 0.01)
        vertexData[61].position = (  0,     -y / 2 - 2,      z / 2 + x / 2 * 5 / 12 + 0.01)
        vertexData[62].position = (  0,      -y / 2 - 2,     z / 2 + x / 2 * 5 / 12 - 1 + 0.01)
        vertexData[63].position = vertexData[62].position
        vertexData[64].position = ( x / 2 + 2,      -y / 2 - 2,     z / 2 - 2 * 5 / 12 - 1 + 0.01)
        vertexData[65].position = vertexData[60].position
        
        //southwest coping
        vertexData[66].position = (0,     -y / 2 - 2,      z / 2 + x / 2 * 5 / 12 + 0.01)
        vertexData[67].position = (  -x / 2 - 2,     -y / 2 - 2,      z / 2 - 2 * 5 / 12 + 0.01)
        vertexData[68].position = (  -x / 2 - 2,      -y / 2 - 2,     z / 2 - 2 * 5 / 12 - 1 + 0.01)
        vertexData[69].position = vertexData[68].position
        vertexData[70].position = (0,      -y / 2 - 2,     z / 2 + x / 2 * 5 / 12 - 1 + 0.01)
        vertexData[71].position = vertexData[66].position
        
        for i in 60..<72 {
            vertexData[i].normal.x = 0
            vertexData[i].normal.y = -1
            vertexData[i].normal.z = 0
            
            vertexData[i].diffuseColor.r = c[0]
            vertexData[i].diffuseColor.g = c[1]
            vertexData[i].diffuseColor.b = c[2]
            vertexData[i].diffuseColor.a = c[3]
            vertexData[i].ambientColor.r = c[0]
            vertexData[i].ambientColor.g = c[1]
            vertexData[i].ambientColor.b = c[2]
            vertexData[i].ambientColor.a = c[3]

        }
        
        //northheast coping
        vertexData[72].position = ( 0,     y / 2 + 2,      z / 2 + x / 2 * 5 / 12 + 0.01)
        vertexData[73].position = (  x / 2 + 2,     y / 2 + 2,      z / 2 - 2 * 5 / 12 + 0.01)
        vertexData[74].position = (  x / 2 + 2,      y / 2 + 2,     z / 2 - 2 * 5 / 12 - 1 + 0.01)
        vertexData[75].position = vertexData[74].position
        vertexData[76].position = ( 0,      y / 2 + 2,     z / 2 + x / 2 * 5 / 12 - 1 + 0.01)
        vertexData[77].position = vertexData[72].position
        
        //northwest coping
        vertexData[78].position = ( -x / 2 - 2,      y / 2 + 2,      z / 2 - 2 * 5 / 12 + 0.01)
        vertexData[79].position = ( 0,     y / 2 + 2,      z / 2 + x / 2 * 5 / 12 + 0.01)
        vertexData[80].position = (  0,      y / 2 + 2,     z / 2 + x / 2 * 5 / 12 - 1 + 0.01)
        vertexData[81].position = vertexData[80].position
        vertexData[82].position = (-x / 2 - 2,      y / 2 + 2,     z / 2 - 2 * 5 / 12 - 1 + 0.01)
        vertexData[83].position = vertexData[78].position
        
        for i in 72..<84 {
            vertexData[i].normal.x = 0
            vertexData[i].normal.y = 1
            vertexData[i].normal.z = 0
            
            vertexData[i].diffuseColor.r = c[0]
            vertexData[i].diffuseColor.g = c[1]
            vertexData[i].diffuseColor.b = c[2]
            vertexData[i].diffuseColor.a = c[3]
            vertexData[i].ambientColor.r = c[0]
            vertexData[i].ambientColor.g = c[1]
            vertexData[i].ambientColor.b = c[2]
            vertexData[i].ambientColor.a = c[3]

        }
        
        vertexCount = 84
    }
}
