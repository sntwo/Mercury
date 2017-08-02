//
//  HgRenderer.swift
//  mercury
//
//  Created by Joshua Knapp on 11/10/15.
//  Copyright © 2015 Joshua Knapp. All rights reserved.
//

import Foundation
import MetalKit

final class HgRenderer {
    
    ////////////////////////singleton syntax
    static let sharedInstance = HgRenderer()
    fileprivate init(){}
    ////////////////////////////////////////
    
    static let device: MTLDevice = MTLCreateSystemDefaultDevice()!
    static let library = device.makeDefaultLibrary()!
    static let commandQueue = device.makeCommandQueue()
    
    var view:MTKView? = nil {
        didSet {
            view!.depthStencilPixelFormat = .depth32Float_stencil8
            view!.colorPixelFormat = .bgra8Unorm
            view!.sampleCount = 1
            view!.clearColor = MTLClearColorMake(0.8, 0.8, 0.8, 1.0)
        }
    }

    ///Vertex buffer for drawing full screen quads
    lazy var quadVertexBuffer:MTLBuffer = {
        var quadVerts = Array(repeating: quadVertex(), count: 6)
        quadVerts[0].position = (1,1)  // top right
        quadVerts[0].texture = (1,1)
        quadVerts[1].position = (-1,1) // top left
        quadVerts[1].texture = (0,1)
        quadVerts[2].position = (-1,-1) // bottom left
        quadVerts[2].texture = (0,0)
        quadVerts[3] = quadVerts[2]
        quadVerts[4].position = (1,-1)  // bottom right
        quadVerts[4].texture = (1,0)
        quadVerts[5] = quadVerts[0]
        
        return HgRenderer.device.makeBuffer(bytes: quadVerts,length:MemoryLayout<Float>.size * 24,options:[])
    }()
    
    struct quadVertex {
        var position: (x:Float, y:Float) = (0, 0)
        var texture: (u:Float, v:Float) = (0, 0)
    }
    
    //MARK:- Rendering
    func renderShadowBuffer(nodes:[HgNode]) {
        //not yet implemented
    }
    
    func renderGBuffer(nodes:[HgNode], box:HgSkyboxNode, commandBuffer:MTLCommandBuffer) {
       
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: gBufferRenderPassDescriptor)
        encoder.label = "g buffer"
        encoder.setDepthStencilState(gBufferDepthStencilState)
        encoder.setCullMode(.back)
        
        //encoder.pushDebugGroup("skybox")
        
        encoder.setVertexBuffer(box.vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(box.uniformBuffer, offset: 0, index: 1)
        
        if let sbt = box.texture {
            encoder.setRenderPipelineState(skyboxRenderPipeline)
            encoder.setFragmentTexture(sbt, index: 0)
        }
        else {
            encoder.setRenderPipelineState(skyboxRenderPipelineUntextured)
            //encoder.setFragmentTexture(skyboxTexture, atIndex: 0)
        }
    
        //encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: box.vertexCount)
        
        encoder.setRenderPipelineState(gBufferRenderPipeline)
       
        for node in nodes {
            guard node.vertexCount > 0 else { continue }
            encoder.setVertexBuffer(node.vertexBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(node.uniformBuffer, offset: 0, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: node.vertexCount)
        }
        encoder.popDebugGroup()
        encoder.endEncoding()
    }
    
    func renderLightBuffer(lights:[HgLightNode], commandBuffer:MTLCommandBuffer) {
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: lightBufferRenderPassDescriptor)
        encoder.label = "light"
        //encoder.setDepthStencilState(lightBufferDepthStencilState)
        encoder.pushDebugGroup("lightBuffer")
        encoder.setRenderPipelineState(lightBufferRenderPipeline)
        
        encoder.setFragmentTexture(gBufferNormalTexture, index: 0)
        encoder.setFragmentTexture(gBufferModelPositionTexture, index: 1)
        //encoder.setCullMode(.Front)
        
        for node in lights {
            guard node.vertexCount > 0 else { continue }
            encoder.setVertexBuffer(node.vertexBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(node.uniformBuffer, offset: 0, index: 1)
            encoder.setFragmentBuffer(node.lightDataBuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 12)
        }
        encoder.popDebugGroup()
        encoder.endEncoding()
    }
    
    lazy var uniformBuffer:MTLBuffer = {
        let uniformSize = 2 * MemoryLayout<Float>.size
        let buffer = HgRenderer.device.makeBuffer(length: uniformSize, options: [])
        
        struct sizeStruct {
            let width:Float
            let height:Float
        }
        
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        
        let x = Float(v.frame.size.width)
        let y = Float(v.frame.size.height)
        //print("supplied \(x) and \(y)")
        
        var ss = sizeStruct(width: x, height: y)
        memcpy(buffer.contents(), &ss, MemoryLayout<Float>.size * 2)
        return buffer
    }()

    func render(nodes:[HgNode], lights:[HgLightNode], box:HgSkyboxNode){
    
        guard let v = HgRenderer.sharedInstance.view else {print("could not get view"); return}
        guard let renderPassDescriptor = v.currentRenderPassDescriptor else { print("could not get rpd");return }
    
        //dispatch_semaphore_wait(inflightSemaphore, DISPATCH_TIME_FOREVER)
        
        let commandBuffer = HgRenderer.commandQueue.makeCommandBuffer()
        
        // 1st pass (shadow depth texture pass)
        renderShadowBuffer(nodes: nodes)
        
        // 2nd pass (gbuffer)
        renderGBuffer(nodes:nodes, box:box, commandBuffer: commandBuffer)
        
        // 3rd pass (light buffer)
        renderLightBuffer(lights:lights, commandBuffer: commandBuffer)
        
        // 4th pass (composition)
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: compositionRenderPassDescriptor)
        renderEncoder.label = "composition"
        renderEncoder.setRenderPipelineState(compositionRenderPipeline)
        renderEncoder.setDepthStencilState(compositeDepthStencilState)
        renderEncoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(box.scene.uniformBuffer, offset: 0, index: 1) //just getting the light data
        renderEncoder.setFragmentTexture(gBufferAlbedoTexture, index: 0)
        renderEncoder.setFragmentTexture(lightBufferTexture, index: 1)
        renderEncoder.setFragmentTexture(gBufferNormalTexture, index: 2)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart:0, vertexCount:6)
        renderEncoder.endEncoding()
        
        
        //5th pass (post process)
        
        let renderEncoder2 = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        renderEncoder2.label = "post process"
        renderEncoder2.setRenderPipelineState(postRenderPipeline)
        renderEncoder2.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
        renderEncoder2.setVertexBuffer(uniformBuffer, offset: 0, index:1)
        renderEncoder2.setFragmentTexture(compositionTexture, index: 0)
        renderEncoder2.drawPrimitives(type: .triangle, vertexStart:0, vertexCount:6)
        renderEncoder2.endEncoding()
        
        commandBuffer.present(v.currentDrawable!)
        commandBuffer.commit()

    }
 
    //MARK:- Textures
    fileprivate lazy var zBufferTexture: MTLTexture = {
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        let x = Int(v.frame.size.width)
        let y = Int(v.frame.size.height)
        let zbufferTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MTLPixelFormat.depth32Float, width: x, height: y, mipmapped: false)
        zbufferTextureDescriptor.usage = [.renderTarget, .shaderRead]
        zbufferTextureDescriptor.storageMode = .private
        return HgRenderer.device.makeTexture(descriptor: zbufferTextureDescriptor)
    }()
    
    fileprivate lazy var gBufferAlbedoTexture: MTLTexture = {
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        let x = Int(v.frame.size.width)
        let y = Int(v.frame.size.height)

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: x, height: y, mipmapped: false)
        descriptor.sampleCount = 1
        descriptor.storageMode = .private
        descriptor.textureType = .type2D
        descriptor.usage = [.renderTarget, .shaderRead]
        
        return HgRenderer.device.makeTexture(descriptor: descriptor)
    }()
    
    fileprivate lazy var gBufferNormalTexture: MTLTexture = {
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        let x = Int(v.frame.size.width)
        let y = Int(v.frame.size.height)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: x, height: y, mipmapped: false)
        descriptor.sampleCount = 1
        descriptor.storageMode = .private
        descriptor.textureType = .type2D
        descriptor.usage = [.renderTarget, .shaderRead]
        
        return HgRenderer.device.makeTexture(descriptor: descriptor)
    }()
    
    fileprivate lazy var gBufferModelPositionTexture: MTLTexture = {
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        let x = Int(v.frame.size.width)
        let y = Int(v.frame.size.height)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: x, height: y, mipmapped: false)
        descriptor.sampleCount = 1
        descriptor.storageMode = .private
        descriptor.textureType = .type2D
        descriptor.usage = [.renderTarget, .shaderRead]
        
        return HgRenderer.device.makeTexture(descriptor: descriptor)
    }()
    
    fileprivate lazy var lightBufferTexture: MTLTexture = {
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        let x = Int(v.frame.size.width)
        let y = Int(v.frame.size.height)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: x, height: y, mipmapped: false)
        descriptor.sampleCount = 1
        descriptor.storageMode = .private
        descriptor.textureType = .type2D
        descriptor.usage = [.renderTarget, .shaderRead]
        
        return HgRenderer.device.makeTexture(descriptor: descriptor)
    }()
    
    fileprivate lazy var compositionTexture: MTLTexture = {
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        let x = Int(v.frame.size.width)
        let y = Int(v.frame.size.height)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: x, height: y, mipmapped: false)
        descriptor.sampleCount = 1
        descriptor.storageMode = .private
        descriptor.textureType = .type2D
        descriptor.usage = [.renderTarget, .shaderRead]
        
        return HgRenderer.device.makeTexture(descriptor: descriptor)
    }()
    
    fileprivate lazy var gBufferDepthTexture: MTLTexture = {
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        let x = Int(v.frame.size.width)
        let y = Int(v.frame.size.height)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: x, height: y, mipmapped: false)
        descriptor.sampleCount = 1
        descriptor.storageMode = .private
        descriptor.textureType = .type2D
        descriptor.usage = [.renderTarget, .shaderRead]
        
        return HgRenderer.device.makeTexture(descriptor: descriptor)
    }()
    
    fileprivate func loadTexture(_ name:String) -> MTLTexture? {
        if let url = Bundle.main.url(forResource: name, withExtension: ".png"){
            let loader = MTKTextureLoader(device: HgRenderer.device)
            
            do {
                let texture = try loader.newTexture(withContentsOf: url, options:nil)
                print("made skybox texture with format \(texture.pixelFormat.rawValue)")
                return texture
            } catch let error {
                print("Failed to load texture, error \(error)")
                
            }
        }
        return nil
    }
    
    //MARK: Depth and stencil states
    fileprivate lazy var shadowDepthStencilState:MTLDepthStencilState =  {
        let desc = MTLDepthStencilDescriptor()
        desc.isDepthWriteEnabled = true
        desc.depthCompareFunction = .lessEqual
        return HgRenderer.device.makeDepthStencilState(descriptor: desc)
    }()
    
    fileprivate lazy var gBufferDepthStencilState:MTLDepthStencilState = {
        let desc = MTLDepthStencilDescriptor()
        desc.isDepthWriteEnabled = true
        desc.depthCompareFunction = .lessEqual
        return HgRenderer.device.makeDepthStencilState(descriptor: desc)
    }()
    
    fileprivate lazy var compositeDepthStencilState:MTLDepthStencilState = {
        let desc = MTLDepthStencilDescriptor()
        desc.isDepthWriteEnabled = false
        desc.depthCompareFunction = .always
        return HgRenderer.device.makeDepthStencilState(descriptor: desc)
    }()

    
    //MARK: Render pass descriptors
    fileprivate lazy var shadowRenderPassDescriptor: MTLRenderPassDescriptor = {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.depthAttachment.texture = HgRenderer.sharedInstance.zBufferTexture
        descriptor.depthAttachment.loadAction = .clear;
        descriptor.depthAttachment.storeAction = .store;
        descriptor.depthAttachment.clearDepth = 1.0
        return descriptor
    }()
    
    fileprivate lazy var gBufferRenderPassDescriptor: MTLRenderPassDescriptor = {
        let desc = MTLRenderPassDescriptor()
        let color = desc.colorAttachments[0]
        color?.clearColor = MTLClearColorMake(0,0,0,1)
        color?.texture = HgRenderer.sharedInstance.gBufferAlbedoTexture
        color?.loadAction = .clear
        color?.storeAction = .store
        let color2 = desc.colorAttachments[1]
        color2?.texture = HgRenderer.sharedInstance.gBufferNormalTexture
        color2?.loadAction = .clear
        color2?.storeAction = .store
        let color3 = desc.colorAttachments[2]
        color3?.texture = HgRenderer.sharedInstance.gBufferModelPositionTexture
        color3?.loadAction = .clear
        color3?.storeAction = .store

        let depth = desc.depthAttachment
        depth?.loadAction = .clear
        depth?.storeAction = .store
        depth?.texture = HgRenderer.sharedInstance.gBufferDepthTexture
        depth?.clearDepth = 1.0
        return desc
    }()
    
    fileprivate lazy var lightBufferRenderPassDescriptor: MTLRenderPassDescriptor = {
        let desc = MTLRenderPassDescriptor()
        let color = desc.colorAttachments[0]
        color?.clearColor = MTLClearColorMake(0,0,0,1)
        color?.texture = HgRenderer.sharedInstance.lightBufferTexture
        color?.loadAction = .clear
        color?.storeAction = .store
        return desc
    }()
    
    fileprivate lazy var compositionRenderPassDescriptor: MTLRenderPassDescriptor = {
        let desc = MTLRenderPassDescriptor()
        let color = desc.colorAttachments[0]
        color?.clearColor = MTLClearColorMake(0,0,0,1)
        color?.texture = HgRenderer.sharedInstance.compositionTexture
        color?.loadAction = .clear
        color?.storeAction = .store
        return desc
    }()

    
    //MARK: Pipelines
    
    fileprivate static func makeRenderPipelineState(type:String, withDescriptor desc:MTLRenderPipelineDescriptor) -> MTLRenderPipelineState {
        var state:MTLRenderPipelineState
        do {
            try state = HgRenderer.device.makeRenderPipelineState(descriptor: desc)
        } catch let error {
            fatalError("Failed to create \(type) pipeline state, error \(error)")
        }
        return state
    }
    
    fileprivate lazy var skyboxRenderPipeline:MTLRenderPipelineState = {
        let desc = MTLRenderPipelineDescriptor()
        desc.colorAttachments[0].pixelFormat = .rgba8Unorm;
        desc.colorAttachments[1].pixelFormat = .rgba16Float;
        desc.colorAttachments[2].pixelFormat = .rgba16Float;
        desc.depthAttachmentPixelFormat      = .depth32Float;
        desc.sampleCount = 1
        desc.label = "Skybox Render"
        desc.vertexFunction = HgRenderer.library.makeFunction(name: "skyboxVert")
        desc.fragmentFunction = HgRenderer.library.makeFunction(name: "skyboxFrag")
        
        return makeRenderPipelineState(type: "skybox", withDescriptor: desc)
    }()
    
    fileprivate lazy var skyboxRenderPipelineUntextured:MTLRenderPipelineState = {
        let desc = MTLRenderPipelineDescriptor()
        desc.colorAttachments[0].pixelFormat = .rgba8Unorm;
        desc.colorAttachments[1].pixelFormat = .rgba16Float;
        desc.colorAttachments[2].pixelFormat = .rgba16Float;
        desc.depthAttachmentPixelFormat      = .depth32Float;
        desc.sampleCount = 1
        desc.label = "Skybox Render"
        desc.vertexFunction = HgRenderer.library.makeFunction(name: "skyboxVert")
        desc.fragmentFunction = HgRenderer.library.makeFunction(name: "skyboxFragUntextured")
        
        return makeRenderPipelineState(type: "skybox untextured", withDescriptor: desc)
    }()


    fileprivate lazy var gBufferRenderPipeline:MTLRenderPipelineState = {
        let desc = MTLRenderPipelineDescriptor()
        desc.colorAttachments[0].pixelFormat = .rgba8Unorm;
        desc.colorAttachments[1].pixelFormat = .rgba16Float;
        desc.colorAttachments[2].pixelFormat = .rgba16Float;
        desc.depthAttachmentPixelFormat      = .depth32Float;
        desc.sampleCount = 1
        desc.label = "gBuffer Render"
        desc.vertexFunction = HgRenderer.library.makeFunction(name: "gBufferVert")
        desc.fragmentFunction = HgRenderer.library.makeFunction(name: "gBufferFrag")
        
        return makeRenderPipelineState(type: "gBuffer", withDescriptor: desc)
    }()
    
    fileprivate lazy var lightBufferRenderPipeline:MTLRenderPipelineState = {
        let desc = MTLRenderPipelineDescriptor()
        
        let color = desc.colorAttachments[0]
        color?.isBlendingEnabled = true
        color?.rgbBlendOperation = .add
        color?.alphaBlendOperation = .add
        color?.pixelFormat = .bgra8Unorm
        color?.sourceRGBBlendFactor = .one
        color?.sourceAlphaBlendFactor = .one
        color?.destinationAlphaBlendFactor = .one
        color?.destinationRGBBlendFactor = .one

        desc.label = "light Pipeline"
        
        desc.vertexFunction = HgRenderer.library.makeFunction(name: "lightVert")
        desc.fragmentFunction = HgRenderer.library.makeFunction(name: "lightFrag")
        
        return makeRenderPipelineState(type: "light", withDescriptor: desc)
    }()

    fileprivate lazy var compositionRenderPipeline:MTLRenderPipelineState = {
        let desc = MTLRenderPipelineDescriptor()
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm;
        desc.label = "Composition Render"
        desc.vertexFunction = HgRenderer.library.makeFunction(name: "compositionVert")
        desc.fragmentFunction = HgRenderer.library.makeFunction(name: "compositionFrag")
        desc.sampleCount = 1
        
        return makeRenderPipelineState(type: "composite", withDescriptor: desc)
    }()
    
    fileprivate lazy var postRenderPipeline:MTLRenderPipelineState = {
        let desc = MTLRenderPipelineDescriptor()
        desc.colorAttachments[0].pixelFormat = .bgra8Unorm;
        desc.depthAttachmentPixelFormat = .depth32Float_stencil8
        desc.stencilAttachmentPixelFormat = .depth32Float_stencil8

        desc.label = "Post Render"
        desc.vertexFunction = HgRenderer.library.makeFunction(name: "postVert")
        desc.fragmentFunction = HgRenderer.library.makeFunction(name: "postFrag")
        desc.sampleCount = 1
        
        return makeRenderPipelineState(type: "post", withDescriptor: desc)
    }()
    
    fileprivate lazy var spriteRenderPipeline:MTLRenderPipelineState = {
        let desc = MTLRenderPipelineDescriptor()
        desc.label = "Fairy Render"
        desc.vertexFunction = HgRenderer.library.makeFunction(name: "fairyVert")
        desc.fragmentFunction = HgRenderer.library.makeFunction(name: "fairyFrag")
        
        return makeRenderPipelineState(type: "sprite", withDescriptor: desc)
    }()

    fileprivate lazy var shadowRenderPipeline:MTLRenderPipelineState = {
        let desc = MTLRenderPipelineDescriptor()
        desc.label = "Shadow Render Pipeleine"
        desc.vertexFunction = HgRenderer.library.makeFunction(name: "zOnly")
        desc.fragmentFunction = nil
        desc.depthAttachmentPixelFormat = HgRenderer.sharedInstance.zBufferTexture.pixelFormat
        
        return makeRenderPipelineState(type: "shadow", withDescriptor: desc)
    }()
    
    
   
}


