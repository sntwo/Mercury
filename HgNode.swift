
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
        //var ambientColor: (r:Float, g:Float, b:Float, a:Float) = (0.3,0.3,0.3,1)
        var ambientColor: (r:Float, g:Float, b:Float, a:Float) = (1.0,1.0,1.0,1)
        //color of the object in direct light
        //var diffuseColor: (r:Float, g:Float, b:Float, a:Float) = (0.9,0.9,0.9,1)
        var diffuseColor: (r:Float, g:Float, b:Float, a:Float) = (0.64,0.64,0.64,1)
    }
    
    struct uniform {
        
        var modelMatrix: float4x4 = float4x4(scale: float3(1,1,1))
        var projectionMatrix: float4x4 = float4x4(scale: float3(1,1,1))
        var lightMatrix: float4x4 = float4x4(scale: float3(1,1,1))
        var normalMatrix: float3x3 = float3x3(1)
        var lightPosition: float3 = float3(0,0,1)
    }
    
    enum nodeType {
        case textured(String)
        case untextured
    }

   
    fileprivate(set) var children = [HgNode]()
    fileprivate(set) var lights = [HgLightNode]()
    
    weak var parent:HgNode? { didSet { modelMatrixIsDirty = true } }
    
    var position = float3(0,0,1) { didSet { modelMatrixIsDirty = true } }
    var rotation = float3(0,0,0) { didSet { modelMatrixIsDirty = true } }
    var scale = float3(1,1,1) { didSet { modelMatrixIsDirty = true } }
    var type:nodeType = .untextured
    
    var ambientColor:(Float,Float,Float,Float) = (1,1,1,1) { didSet {
        for i in 0..<vertexData.count {
            vertexData[i].ambientColor = ambientColor
        }
        updateVertexBuffer()
        }
    }
    
    func addLight(_ light:HgLightNode){
        light.parent = self
        lights.append(light)
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
            for light in lights {
                light.modelMatrixIsDirty = true
            }
            for child in children {
                child.modelMatrixIsDirty = true
            }
        }
    }
    
    var scene:HgScene { get {   return parent!.scene    }  }
    
    lazy var vertexBuffer:MTLBuffer = {
        let dataSize = self.vertexData.count * MemoryLayout.size(ofValue: self.vertexData[0])
        return HgRenderer.device.makeBuffer(bytes: self.vertexData, length: dataSize, options: [])!
    }()
    
    lazy var uniformBuffer:MTLBuffer = {
        let uniformSize = 4 * MemoryLayout<float4x4>.size + MemoryLayout<float3x3>.size + MemoryLayout<float3>.size
        return HgRenderer.device.makeBuffer(length: uniformSize, options: [])!
    }()
    
    lazy var compositionUniformBuffer:MTLBuffer = {
        let uniformSize = MemoryLayout<float3x3>.size
        return HgRenderer.device.makeBuffer(length: uniformSize, options: [])!
    }()
    
    fileprivate var _texture:MTLTexture?
    
    var texture:MTLTexture? { get {
        
        switch type.self {
            
        case let .textured(tName):
            //print("got tname \(tName)")
            if let t = _texture {
                return t
            } else {
                _texture = HgRenderer.loadTexture(tName)
                return _texture
            }
            
        case .untextured:
            print("error: tried to get texture from untextured node")
            break
            //
        }
        //print("returning nil")
        return nil
        
        } set {
            _texture = newValue
        }
    }
            

    //do we really need this?
    var vertexCount:Int = 0
    
    var vertexData = [vertex]()
    var uniforms = uniform()

    //MARK:- graph functions

    func addChild(_ child: HgNode){
        child.parent = self
        children.append(child)
    }
    
    func removeFromGraph(){
        if let p = parent {
            p.removeChild(self)
        }
    }
    
    func removeChild(_ child:HgNode){
        for (index, element) in children.enumerated() {
            if element === child {
                children.remove(at: index)
                break
            }
        }
    }
    
    // TODO: Do we really want to do this every frame?
    func flattenHeirarchy() -> ([HgNode],[HgNode],[HgLightNode]) {
        var textured:[HgNode]
        var untextured:[HgNode]
        switch type {
        case .textured:
            textured = [self as HgNode]
            untextured = [HgNode]()
        case .untextured:
            untextured = [self as HgNode]
            textured = [HgNode]()
        }
        var lgt = lights
        for node in children {
            let (a,b,c) = node.flattenHeirarchy()
            textured += a
            untextured += b
            lgt += c
        }
        return (textured, untextured, lgt)
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
    func updateNode(_ dt:TimeInterval){
        if modelMatrixIsDirty {
            updateUniformBuffer()
        }
        for light in lights{
            light.updateNode(1/60)
        }
        for child in children{
            child.updateNode(1/60)
        }
    }
    
    func rebuffer(){
        let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
        vertexBuffer = HgRenderer.device.makeBuffer(bytes: vertexData, length: dataSize, options: [])!
    }

    func updateUniformBuffer() {
        
        updateModelMatrix()
        
        uniforms.modelMatrix = modelMatrix
        uniforms.normalMatrix = float3x3(mat4:modelMatrix)
        uniforms.projectionMatrix = scene.projectionMatrix
        uniforms.lightPosition = scene.sunPosition
        
        memcpy(uniformBuffer.contents(), &uniforms, 4 * MemoryLayout<float4x4>.size  + MemoryLayout<float3x3>.size + MemoryLayout<float3>.size)
    }
    
    func updateVertexBuffer() {
        memcpy(vertexBuffer.contents(), &vertexData, MemoryLayout.size(ofValue: vertexData[0]) * vertexData.count)
    }
}
