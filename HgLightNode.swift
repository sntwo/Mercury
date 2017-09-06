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

class HgLightNode:HgPlaneNode {
    
    struct LightFragmentInput{
        var view_light_position:float4
        var light_color_radius: float4
        var light_direction_coherance: float4
        var screen_size: float2
    }
    
    lazy var lightDataBuffer:MTLBuffer = {
        let lsize = 64
        return HgRenderer.device.makeBuffer(length: lsize, options: [])!
    }()
    
    var radius:Float
    var color:float3 = float3(1,1,0.4)
    
    init(radius:Float) {
        self.radius = radius
        super.init(width: radius * 4, length: radius * 4)
    }
    
    
    override func updateUniformBuffer(){
        
        //keep the light quad aligned to the screen
        //let cosr = (cos(scene.rotation.z))
        //let sinr = (sin(scene.rotation.z))
        //self.rotation.x = -scene.rotation.x * cosr
        //self.rotation.y = scene.rotation.x * sinr
        //self.rotation.z = -scene.rotation.z
            
        super.updateUniformBuffer()
        
        if let view = HgRenderer.sharedInstance.view {
            
            //let color = normalize(float3(1,1,0))
            let pos = modelMatrix * float4(position.x, position.y, position.z, 1.0)
            var lightData = LightFragmentInput(view_light_position: pos,
                                            light_color_radius: float4(color.x,color.y,color.z,radius),
                                            light_direction_coherance: float4(0,0,1,0),
                                            screen_size: float2(Float(view.frame.size.width),Float(view.frame.size.height))
                                            )
            
            memcpy(lightDataBuffer.contents(), &lightData, 64)
            //print("made lightdatabuffer")
        }
    }
}
