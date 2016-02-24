
//
//  S2Node.swift
//  S2SWEngine
//
//  Created by Joshua Knapp on 6/7/14.
//  Copyright (c) 2014 Joshua Knapp. All rights reserved.
//

//import Foundation
import Metal
import simd
import MetalKit


class HgNode {
    
    struct vertex {
        var position: (x:Float, y:Float, z:Float) = (0, 0, 0)
        var normal: (x:Float, y:Float, z:Float) = (0, 0, 1)
        
        /// (0, 0) is top left, (1, 1) is bottom right
        var texture: (u:Float, v:Float) = (0, 0)
        //color of the object in shadow
        var ambientColor: (r:Float, g:Float, b:Float, a:Float) = (0.3,0.3,0.3,1)
        //color of the object in direct light
        var diffuseColor: (r:Float, g:Float, b:Float, a:Float) = (0.9,0.9,0.9,1)
    }
    
    struct uniform {
        
        var modelMatrix: float4x4 = float4x4(scale: float3(1,1,1))
        var projectionMatrix: float4x4 = float4x4(scale: float3(1,1,1))
        var lightMatrix: float4x4 = float4x4(scale: float3(1,1,1))
        var normalMatrix: float3x3 = float3x3(1)
        var lightPosition: float3 = float3(0,0,1)
    }

   
    private(set) var children = [HgNode]()
    
    weak var parent:HgNode? { didSet { modelMatrixIsDirty = true } }
    
    var position = float3(0,0,1) { didSet { modelMatrixIsDirty = true } }
    var rotation = float3(0,0,0) { didSet { modelMatrixIsDirty = true } }
    var scale = float3(1,1,1) { didSet { modelMatrixIsDirty = true } }
    
    var ambientColor:(Float,Float,Float,Float) = (1,1,1,1) { didSet {
        for i in 0..<vertexData.count {
            vertexData[i].ambientColor = ambientColor
        }
        updateVertexBuffer()
        }
    }
    
    var diffuseColor:(Float,Float,Float,Float) = (1,1,1,1) { didSet {
        for i in 0..<vertexData.count {
            vertexData[i].diffuseColor = diffuseColor
        }
        updateVertexBuffer()
        }
    }
    
    var modelMatrix = float4x4(1)
    
    var modelMatrixIsDirty = true {
        didSet {
            for child in children {
                child.modelMatrixIsDirty = true
            }
        }
    }
    
    var scene:HgScene { get {   return parent!.scene    }   }
    
    lazy var vertexBuffer:MTLBuffer = {
        
        let dataSize = self.vertexData.count * sizeofValue(self.vertexData[0])
        print("making vertex buffer with \(self.vertexData.count) vertices and size \(dataSize)")
        return HgRenderer.device.newBufferWithBytes(self.vertexData, length: dataSize, options: [])
    }()
    
    lazy var uniformBuffer:MTLBuffer = {
        let uniformSize = 4 * sizeof(float4x4) + sizeof(float3x3) + sizeof(float3)
        return HgRenderer.device.newBufferWithLength(uniformSize, options: [])
    }()
    
    lazy var compositionUniformBuffer:MTLBuffer = {
        let uniformSize = sizeof(float3x3)
        return HgRenderer.device.newBufferWithLength(uniformSize, options: [])
    }()

    //do we really need this?
    var vertexCount:Int = 0
    
    var vertexData = [vertex]()
    var uniforms = uniform()

    //MARK:- graph functions
    func addChild(child: HgNode){
        child.parent = self
        children.append(child)
    }
    
    func removeFromGraph(){
        if let p = parent {
            p.removeChild(self)
        }
    }
    
    func removeChild(child:HgNode){
        for (index, element) in children.enumerate() {
            if element === child {
                children.removeAtIndex(index)
                break
            }
        }
    }
        
    func flattenHeirarchy() -> [HgNode] {
        var ret = [self as HgNode]
        for node in children {
            ret += node.flattenHeirarchy()
        }
        return ret
    }
    
    func updateModelMatrix(){
        
        let x = float4x4(XRotation: rotation.x)
        let y = float4x4(YRotation: rotation.y)
        let z = float4x4(ZRotation: rotation.z)
        let t = float4x4(translation: position)
        let s = float4x4(scale: scale)
        var m = t * s * x * y * z

        if let p = self.parent {
            m = p.modelMatrix * m
        }
        
        modelMatrix = m
        modelMatrixIsDirty = false
        
    }

    //MARK:- Render functions
    func updateNode(dt:NSTimeInterval){
        if modelMatrixIsDirty {
            updateUniformBuffer()
        }
        
        for child in children{
            child.updateNode(1/60)
        }
    }
    
    func updateUniformBuffer() {
        
        updateModelMatrix()
        
        uniforms.modelMatrix = modelMatrix
        uniforms.normalMatrix = float3x3(mat4:modelMatrix)
        uniforms.projectionMatrix = scene.projectionMatrix
        //uniforms.lightMatrix = scene!.lightMatrix
        uniforms.lightPosition = scene.lightPosition
        memcpy(uniformBuffer.contents(), &uniforms, 4 * sizeof(float4x4)  + sizeof(float3x3) + sizeof(float3))
    }
    
    func updateVertexBuffer() {
        memcpy(vertexBuffer.contents(), &vertexData, sizeofValue(vertexData[0]) * vertexData.count)
    }
}