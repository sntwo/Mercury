//
//  HgLightNode.swift
//  Mercury
//
//  Created by Joshua Knapp on 12/22/15.
//
//

import Foundation
import Foundation
import Metal
import simd

class HgLightNode:HgNode {
    
    struct LightFragmentInput{
        var view_light_position:float4
        var light_color_radius: float4
        var screen_size: float2
    }
    
    lazy var indexBuffer:MTLBuffer = {
        let uniformSize = 60 * sizeof(UInt16)
        return HgRenderer.device.newBufferWithLength(uniformSize, options: [])
    }()
    
    lazy var lightDataBuffer:MTLBuffer = {
        let lsize = 48
        return HgRenderer.device.newBufferWithLength(lsize, options: [])
    }()
    
    init(radius:Float) {
        super.init()
        
        
        
        //define an icosahedron
        let X = radius / 0.755761314076171 // = radius / sqrtf(3.0) / 12.0 * (3.0 + sqrtf(5.0))
        let Z = X * (1.0 + sqrtf(5.0)) / 2.0
        
        vertexData = Array(count: 12, repeatedValue: vertex())
        vertexData[0].position = (-X, 0, Z)
        vertexData[1].position = (X, 0, Z)
        vertexData[2].position = (-X, 0, -Z)
        vertexData[3].position = (X, 0, -Z)
        vertexData[4].position = (0, Z, X)
        vertexData[5].position = (0, Z, -X)
        vertexData[6].position = (0, -Z, X)
        vertexData[7].position = (0, -Z, -X)
        vertexData[8].position = (Z, X, 0)
        vertexData[9].position = (-Z, X, 0)
        vertexData[10].position = (Z, -X, 0)
        vertexData[11].position = (-Z,-X, 0)
        
        vertexCount = 12
        
        updateVertexBuffer()
        
        let indices:[UInt16] = [0, 1, 4, 0, 4, 9, 9, 4, 5, 4, 8, 5, 4, 1, 8, 8, 1, 10, 8, 10, 3, 5, 8, 3, 5, 3, 2, 2, 3, 7, 7, 3, 10, 7, 10, 6, 7, 6, 11, 11, 6, 0, 0, 6, 1, 6, 10, 1, 9, 11, 0, 9, 2, 11, 9, 5, 2, 7, 11, 2]
        
        memcpy(indexBuffer.contents(), indices, 60 * sizeof(UInt16))
        
    }
    
    override func updateUniformBuffer(){
        super.updateUniformBuffer()
        if let view = HgRenderer.sharedInstance.view {
            
            let color = normalize(float3(1,0,1))
            let pos = modelMatrix * float4(position.x, position.y, position.z, 1.0)
            var lightData = LightFragmentInput(view_light_position: pos, light_color_radius: float4(color.x,color.y,color.z,1), screen_size: float2(Float(view.frame.size.width), Float(view.frame.size.height)))
            
            memcpy(lightDataBuffer.contents(), &lightData, 40)
            print("made lightdatabuffer")
        }
    }
}