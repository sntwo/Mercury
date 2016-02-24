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
        defer { self.updateVertexBuffer() }
    
        super.init()
        
         vertexData = Array(count: 84, repeatedValue: vertex())
        
        //describe faces indices thusly: left wound
        //   + 1.......0,5
        //     .      / .
        //     .     /  .
        //     .    /   .
        //     .  /     .
        //     2,3......4  +
        //
        //      axes: up(y axis), right(x axis), and toward viewer(z axis) are positive
        
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
        
        
        let rand = random(0, high: housediffuseColors.count - 1)
        let h = housediffuseColors[rand]
        
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
        vertexData[31].position = ( x / 2 + 2,     y / 2 + 2,      z / 2 - 2 * 5 / 12 + 0.01)
        vertexData[30].position = ( 0,      y / 2 + 2,      z / 2 + x / 2 * 5 / 12 + 0.01)
        vertexData[32].position = ( 0,      -y / 2 - 2,     z / 2 + x / 2 * 5 / 12 + 0.01)
        vertexData[33].position = vertexData[32].position
        vertexData[35].position = ( x / 2 + 2,       -y / 2 - 2,     z / 2 - 2 * 5 / 12 + 0.01)
        vertexData[34].position = vertexData[31].position
        
        
        //The roof slope is 5/12, so the normal will be 12/5
        let n = normalize(float3(12, 0, 5))
        for i in 30..<36 {
            vertexData[i].normal.x = n.x
            vertexData[i].normal.y = n.y
            vertexData[i].normal.z = n.z
        }
        
        
        //west roof
        vertexData[37].position = ( 0,     y / 2 + 2,      z / 2 + x / 2 * 5 / 12 + 0.01)
        vertexData[36].position = ( -x / 2 - 2,       y / 2 + 2,      z / 2 - 2 * 5 / 12 + 0.01)
        vertexData[38].position = ( -x / 2 - 2,      -y / 2 - 2,     z / 2 - 2 * 5 / 12 + 0.01)
        vertexData[39].position = vertexData[38].position
        vertexData[41].position = ( 0,       -y / 2 - 2,     z / 2 + x / 2 * 5 / 12 + 0.01)
        vertexData[40].position = vertexData[37].position
        
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
        vertexData[43].position = (-x / 2, y / 2, z / 2)
        vertexData[42].position = (0, y / 2, z / 2 + x / 2 * 5 / 12)
        vertexData[44].position = (x / 2, y / 2, z / 2)
        vertexData[42].normal = (0, 1, 0)
        vertexData[43].normal = (0, 1, 0)
        vertexData[44].normal = (0, 1, 0)
        
        //south triangle
        vertexData[46].position = (x / 2, -y / 2, z / 2)
        vertexData[45].position = (0, -y / 2, z / 2 + x / 2 * 5 / 12)
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
        vertexData[49].position = ( x / 2 + 2,     y / 2 + 2,      z / 2 - 2 * 5 / 12  + 0.01)
        vertexData[48].position = (  x / 2 + 2,     -y / 2 - 2,      z / 2 - 2 * 5 / 12 + 0.01)
        vertexData[50].position = (  x / 2 + 2,      -y / 2 - 2,     z / 2 - 2 * 5 / 12 - 1 + 0.01)
        vertexData[51].position = vertexData[50].position
        vertexData[53].position = ( x / 2 + 2,       y / 2 + 2,     z / 2 - 2 * 5 / 12 - 1 + 0.01)
        vertexData[52].position = vertexData[49].position
        
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
        vertexData[55].position = ( -x / 2 - 2,     -y / 2 - 2,      z / 2 - 2 * 5 / 12 + 0.01)
        vertexData[54].position = (  -x / 2 - 2,     y / 2 + 2,      z / 2 - 2 * 5 / 12 + 0.01)
        vertexData[56].position = (  -x / 2 - 2,      y / 2 + 2,     z / 2 - 2 * 5 / 12 - 1 + 0.01)
        vertexData[57].position = vertexData[56].position
        vertexData[59].position = ( -x / 2 - 2,       -y / 2 - 2,     z / 2 - 2 * 5 / 12 - 1 + 0.01)
        vertexData[58].position = vertexData[55].position
        
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
        vertexData[61].position = ( x / 2 + 2,     -y / 2 - 2,      z / 2 - 2 * 5 / 12  + 0.01)
        vertexData[60].position = (  0,     -y / 2 - 2,      z / 2 + x / 2 * 5 / 12 + 0.01)
        vertexData[62].position = (  0,      -y / 2 - 2,     z / 2 + x / 2 * 5 / 12 - 1 + 0.01)
        vertexData[63].position = vertexData[62].position
        vertexData[65].position = ( x / 2 + 2,      -y / 2 - 2,     z / 2 - 2 * 5 / 12 - 1 + 0.01)
        vertexData[64].position = vertexData[61].position
        
        //southwest coping
        vertexData[67].position = (0,     -y / 2 - 2,      z / 2 + x / 2 * 5 / 12 + 0.01)
        vertexData[66].position = (  -x / 2 - 2,     -y / 2 - 2,      z / 2 - 2 * 5 / 12 + 0.01)
        vertexData[68].position = (  -x / 2 - 2,      -y / 2 - 2,     z / 2 - 2 * 5 / 12 - 1 + 0.01)
        vertexData[69].position = vertexData[68].position
        vertexData[71].position = (0,      -y / 2 - 2,     z / 2 + x / 2 * 5 / 12 - 1 + 0.01)
        vertexData[70].position = vertexData[67].position
        
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
        vertexData[73].position = ( 0,     y / 2 + 2,      z / 2 + x / 2 * 5 / 12 + 0.01)
        vertexData[72].position = (  x / 2 + 2,     y / 2 + 2,      z / 2 - 2 * 5 / 12 + 0.01)
        vertexData[74].position = (  x / 2 + 2,      y / 2 + 2,     z / 2 - 2 * 5 / 12 - 1 + 0.01)
        vertexData[75].position = vertexData[74].position
        vertexData[77].position = ( 0,      y / 2 + 2,     z / 2 + x / 2 * 5 / 12 - 1 + 0.01)
        vertexData[76].position = vertexData[73].position
        
        //northwest coping
        vertexData[79].position = ( -x / 2 - 2,      y / 2 + 2,      z / 2 - 2 * 5 / 12 + 0.01)
        vertexData[78].position = ( 0,     y / 2 + 2,      z / 2 + x / 2 * 5 / 12 + 0.01)
        vertexData[80].position = (  0,      y / 2 + 2,     z / 2 + x / 2 * 5 / 12 - 1 + 0.01)
        vertexData[81].position = vertexData[80].position
        vertexData[83].position = (-x / 2 - 2,      y / 2 + 2,     z / 2 - 2 * 5 / 12 - 1 + 0.01)
        vertexData[82].position = vertexData[79].position
        
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
