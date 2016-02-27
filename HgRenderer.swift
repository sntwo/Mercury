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
    private init(){}
    ////////////////////////////////////////
    
    static let device: MTLDevice = MTLCreateSystemDefaultDevice()!
    static let library = device.newDefaultLibrary()!
    static let commandQueue = device.newCommandQueue()
    
    var view:MTKView? = nil {
        didSet {
            view!.depthStencilPixelFormat = .Depth32Float_Stencil8
            view!.colorPixelFormat = .BGRA8Unorm
            view!.sampleCount = 1
            view!.clearColor = MTLClearColorMake(0.8, 0.8, 0.8, 1.0)
        }
    }

    ///Vertex buffer for drawing full screen quads
    lazy var quadVertexBuffer:MTLBuffer = {
        var quadVerts = Array(count: 6, repeatedValue: quadVertex())
        quadVerts[0].position = (-1,1) // top left
        quadVerts[0].texture = (0,0)
        quadVerts[1].position = (1,1)  // top right
        quadVerts[1].texture = (1,0)
        quadVerts[2].position = (1,-1)  // bottom right
        quadVerts[2].texture = (1,1)
        quadVerts[3] = quadVerts[0]
        quadVerts[4] = quadVerts[2]
        quadVerts[5].position = (-1,-1) // bottom left
        quadVerts[5].texture = (0,1)

        return HgRenderer.device.newBufferWithBytes(quadVerts,length:sizeof(Float) * 24,options:[])
    }()
    
    struct quadVertex {
        var position: (x:Float, y:Float) = (0, 0)
        var texture: (u:Float, v:Float) = (0, 0)
    }
    
    //MARK:- Rendering
    func renderShadowBuffer(nodes nodes:[HgNode]) {
        //not yet implemented
    }
    
    func renderGBuffer(nodes nodes:[HgNode], box:HgSkyboxNode, commandBuffer:MTLCommandBuffer) {
       
        let encoder = commandBuffer.renderCommandEncoderWithDescriptor(gBufferRenderPassDescriptor)
        encoder.label = "g buffer"
        encoder.setDepthStencilState(gBufferDepthStencilState)
        encoder.setCullMode(.Back)
        
        //encoder.pushDebugGroup("skybox")
        
        encoder.setVertexBuffer(box.vertexBuffer, offset: 0, atIndex: 0)
        encoder.setVertexBuffer(box.uniformBuffer, offset: 0, atIndex: 1)
        
        if let sbt = box.texture {
            encoder.setRenderPipelineState(skyboxRenderPipeline)
            encoder.setFragmentTexture(sbt, atIndex: 0)
        }
        else {
            encoder.setRenderPipelineState(skyboxRenderPipelineUntextured)
            //encoder.setFragmentTexture(skyboxTexture, atIndex: 0)
        }
    
        encoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: box.vertexCount)
        
        encoder.setRenderPipelineState(gBufferRenderPipeline)
       
        for node in nodes {
            guard node.vertexCount > 0 else { continue }
            encoder.setVertexBuffer(node.vertexBuffer, offset: 0, atIndex: 0)
            encoder.setVertexBuffer(node.uniformBuffer, offset: 0, atIndex: 1)
            encoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: node.vertexCount)
        }
        encoder.popDebugGroup()
        encoder.endEncoding()
    }
    
    func renderLightBuffer(lights lights:[HgLightNode], commandBuffer:MTLCommandBuffer) {
        let encoder = commandBuffer.renderCommandEncoderWithDescriptor(lightBufferRenderPassDescriptor)
        encoder.label = "light"
        //encoder.setDepthStencilState(lightBufferDepthStencilState)
        encoder.pushDebugGroup("lightBuffer")
        encoder.setRenderPipelineState(lightBufferRenderPipeline)
        
        encoder.setFragmentTexture(gBufferNormalTexture, atIndex: 0)
        encoder.setFragmentTexture(gBufferModelPositionTexture, atIndex: 1)
        //encoder.setCullMode(.Front)
        
        for node in lights {
            guard node.vertexCount > 0 else { continue }
            encoder.setVertexBuffer(node.vertexBuffer, offset: 0, atIndex: 0)
            encoder.setVertexBuffer(node.uniformBuffer, offset: 0, atIndex: 1)
            encoder.setFragmentBuffer(node.lightDataBuffer, offset: 0, atIndex: 0)
            encoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: 12)
        }
        encoder.popDebugGroup()
        encoder.endEncoding()
    }
    
    lazy var uniformBuffer:MTLBuffer = {
        let uniformSize = 2 * sizeof(Float)
        let buffer = HgRenderer.device.newBufferWithLength(uniformSize, options: [])
        
        struct sizeStruct {
            let width:Float
            let height:Float
        }
        
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        
        let x = Float(v.frame.size.width)
        let y = Float(v.frame.size.height)
        print("supplied \(x) and \(y)")
        
        var ss = sizeStruct(width: x, height: y)
        memcpy(buffer.contents(), &ss, sizeof(Float) * 2)
        return buffer
    }()

    func render(nodes nodes:[HgNode], lights:[HgLightNode], box:HgSkyboxNode){
    
        guard let v = HgRenderer.sharedInstance.view else {print("could not get view"); return}
        guard let renderPassDescriptor = v.currentRenderPassDescriptor else { print("could not get rpd");return }
    
        //dispatch_semaphore_wait(inflightSemaphore, DISPATCH_TIME_FOREVER)
        
        let commandBuffer = HgRenderer.commandQueue.commandBuffer()
        
        // 1st pass (shadow depth texture pass)
        renderShadowBuffer(nodes: nodes)
        
        // 2nd pass (gbuffer)
        renderGBuffer(nodes:nodes, box:box, commandBuffer: commandBuffer)
        
        // 3rd pass (light buffer)
        renderLightBuffer(lights:lights, commandBuffer: commandBuffer)
        
        // 4th pass (composition)
        let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(compositionRenderPassDescriptor)
        renderEncoder.label = "composition"
        renderEncoder.setRenderPipelineState(compositionRenderPipeline)
        renderEncoder.setDepthStencilState(compositeDepthStencilState)
        renderEncoder.setVertexBuffer(quadVertexBuffer, offset: 0, atIndex: 0)
        renderEncoder.setVertexBuffer(box.scene.uniformBuffer, offset: 0, atIndex: 1) //just getting the light data
        renderEncoder.setFragmentTexture(gBufferAlbedoTexture, atIndex: 0)
        renderEncoder.setFragmentTexture(lightBufferTexture, atIndex: 1)
        renderEncoder.setFragmentTexture(gBufferNormalTexture, atIndex: 2)
        renderEncoder.drawPrimitives(.Triangle, vertexStart:0, vertexCount:6)
        renderEncoder.endEncoding()
        
        
        //5th pass (post process)
        let renderEncoder2 = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
        renderEncoder2.label = "post process"
        renderEncoder2.setRenderPipelineState(postRenderPipeline)
        renderEncoder2.setVertexBuffer(quadVertexBuffer, offset: 0, atIndex: 0)
        renderEncoder2.setVertexBuffer(uniformBuffer, offset: 0, atIndex:1)
        renderEncoder2.setFragmentTexture(compositionTexture, atIndex: 0)
        renderEncoder2.drawPrimitives(.Triangle, vertexStart:0, vertexCount:6)
        renderEncoder2.endEncoding()
        
        commandBuffer.presentDrawable(v.currentDrawable!)
        commandBuffer.commit()

    }
 
    //MARK:- Textures
    private lazy var zBufferTexture: MTLTexture = {
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        let x = Int(v.frame.size.width)
        let y = Int(v.frame.size.height)
        let zbufferTextureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(MTLPixelFormat.Depth32Float, width: x, height: y, mipmapped: false)
        zbufferTextureDescriptor.usage = [.RenderTarget, .ShaderRead]
        zbufferTextureDescriptor.storageMode = .Private
        return HgRenderer.device.newTextureWithDescriptor(zbufferTextureDescriptor)
    }()
    
    private lazy var gBufferAlbedoTexture: MTLTexture = {
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        let x = Int(v.frame.size.width)
        let y = Int(v.frame.size.height)

        let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.RGBA8Unorm, width: x, height: y, mipmapped: false)
        descriptor.sampleCount = 1
        descriptor.storageMode = .Private
        descriptor.textureType = .Type2D
        descriptor.usage = [.RenderTarget, .ShaderRead]
        
        return HgRenderer.device.newTextureWithDescriptor(descriptor)
    }()
    
    private lazy var gBufferNormalTexture: MTLTexture = {
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        let x = Int(v.frame.size.width)
        let y = Int(v.frame.size.height)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.RGBA16Float, width: x, height: y, mipmapped: false)
        descriptor.sampleCount = 1
        descriptor.storageMode = .Private
        descriptor.textureType = .Type2D
        descriptor.usage = [.RenderTarget, .ShaderRead]
        
        return HgRenderer.device.newTextureWithDescriptor(descriptor)
    }()
    
    private lazy var gBufferModelPositionTexture: MTLTexture = {
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        let x = Int(v.frame.size.width)
        let y = Int(v.frame.size.height)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.RGBA16Float, width: x, height: y, mipmapped: false)
        descriptor.sampleCount = 1
        descriptor.storageMode = .Private
        descriptor.textureType = .Type2D
        descriptor.usage = [.RenderTarget, .ShaderRead]
        
        return HgRenderer.device.newTextureWithDescriptor(descriptor)
    }()
    
    private lazy var lightBufferTexture: MTLTexture = {
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        let x = Int(v.frame.size.width)
        let y = Int(v.frame.size.height)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.BGRA8Unorm, width: x, height: y, mipmapped: false)
        descriptor.sampleCount = 1
        descriptor.storageMode = .Private
        descriptor.textureType = .Type2D
        descriptor.usage = [.RenderTarget, .ShaderRead]
        
        return HgRenderer.device.newTextureWithDescriptor(descriptor)
    }()
    
    private lazy var compositionTexture: MTLTexture = {
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        let x = Int(v.frame.size.width)
        let y = Int(v.frame.size.height)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.BGRA8Unorm, width: x, height: y, mipmapped: false)
        descriptor.sampleCount = 1
        descriptor.storageMode = .Private
        descriptor.textureType = .Type2D
        descriptor.usage = [.RenderTarget, .ShaderRead]
        
        return HgRenderer.device.newTextureWithDescriptor(descriptor)
    }()
    
    private lazy var gBufferDepthTexture: MTLTexture = {
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        let x = Int(v.frame.size.width)
        let y = Int(v.frame.size.height)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.Depth32Float, width: x, height: y, mipmapped: false)
        descriptor.sampleCount = 1
        descriptor.storageMode = .Private
        descriptor.textureType = .Type2D
        descriptor.usage = [.RenderTarget, .ShaderRead]
        
        return HgRenderer.device.newTextureWithDescriptor(descriptor)
    }()
    
    private func loadTexture(name:String) -> MTLTexture? {
        if let url = NSBundle.mainBundle().URLForResource(name, withExtension: ".png"){
            let loader = MTKTextureLoader(device: HgRenderer.device)
            
            do {
                let texture = try loader.newTextureWithContentsOfURL(url, options:nil)
                print("made skybox texture with format \(texture.pixelFormat.rawValue)")
                return texture
            } catch let error {
                print("Failed to load texture, error \(error)")
                
            }
        }
        return nil
    }
    
    //MARK: Depth and stencil states
    private lazy var shadowDepthStencilState:MTLDepthStencilState =  {
        let desc = MTLDepthStencilDescriptor()
        desc.depthWriteEnabled = true
        desc.depthCompareFunction = .LessEqual
        return HgRenderer.device.newDepthStencilStateWithDescriptor(desc)
    }()
    
    private lazy var gBufferDepthStencilState:MTLDepthStencilState = {
        let desc = MTLDepthStencilDescriptor()
        desc.depthWriteEnabled = true
        desc.depthCompareFunction = .LessEqual
        return HgRenderer.device.newDepthStencilStateWithDescriptor(desc)
    }()
    
    private lazy var compositeDepthStencilState:MTLDepthStencilState = {
        let desc = MTLDepthStencilDescriptor()
        desc.depthWriteEnabled = false
        desc.depthCompareFunction = .Always
        return HgRenderer.device.newDepthStencilStateWithDescriptor(desc)
    }()

    
    //MARK: Render pass descriptors
    private lazy var shadowRenderPassDescriptor: MTLRenderPassDescriptor = {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.depthAttachment.texture = HgRenderer.sharedInstance.zBufferTexture
        descriptor.depthAttachment.loadAction = .Clear;
        descriptor.depthAttachment.storeAction = .Store;
        descriptor.depthAttachment.clearDepth = 1.0
        return descriptor
    }()
    
    private lazy var gBufferRenderPassDescriptor: MTLRenderPassDescriptor = {
        let desc = MTLRenderPassDescriptor()
        let color = desc.colorAttachments[0]
        color.clearColor = MTLClearColorMake(0,0,0,1)
        color.texture = HgRenderer.sharedInstance.gBufferAlbedoTexture
        color.loadAction = .Clear
        color.storeAction = .Store
        let color2 = desc.colorAttachments[1]
        color2.texture = HgRenderer.sharedInstance.gBufferNormalTexture
        color2.loadAction = .Clear
        color2.storeAction = .Store
        let color3 = desc.colorAttachments[2]
        color3.texture = HgRenderer.sharedInstance.gBufferModelPositionTexture
        color3.loadAction = .Clear
        color3.storeAction = .Store

        let depth = desc.depthAttachment
        depth.loadAction = .Clear
        depth.storeAction = .Store
        depth.texture = HgRenderer.sharedInstance.gBufferDepthTexture
        depth.clearDepth = 1.0
        return desc
    }()
    
    private lazy var lightBufferRenderPassDescriptor: MTLRenderPassDescriptor = {
        let desc = MTLRenderPassDescriptor()
        let color = desc.colorAttachments[0]
        color.clearColor = MTLClearColorMake(0,0,0,1)
        color.texture = HgRenderer.sharedInstance.lightBufferTexture
        color.loadAction = .Clear
        color.storeAction = .Store
        return desc
    }()
    
    private lazy var compositionRenderPassDescriptor: MTLRenderPassDescriptor = {
        let desc = MTLRenderPassDescriptor()
        let color = desc.colorAttachments[0]
        color.clearColor = MTLClearColorMake(0,0,0,1)
        color.texture = HgRenderer.sharedInstance.compositionTexture
        color.loadAction = .Clear
        color.storeAction = .Store
        return desc
    }()

    
    //MARK: Pipelines
    private lazy var skyboxRenderPipeline:MTLRenderPipelineState = {
        let desc = MTLRenderPipelineDescriptor()
        desc.colorAttachments[0].pixelFormat = .RGBA8Unorm;
        desc.colorAttachments[1].pixelFormat = .RGBA16Float;
        desc.colorAttachments[2].pixelFormat = .RGBA16Float;
        desc.depthAttachmentPixelFormat      = .Depth32Float;
        desc.sampleCount = 1
        desc.label = "Skybox Render"
        desc.vertexFunction = HgRenderer.library.newFunctionWithName("skyboxVert")
        desc.fragmentFunction = HgRenderer.library.newFunctionWithName("skyboxFrag")
        var state:MTLRenderPipelineState
        do {
            try state = HgRenderer.device.newRenderPipelineStateWithDescriptor(desc)
        } catch let error {
            fatalError("Failed to create skybox pipeline state, error \(error)")
        }
        return state
    }()
    
    private lazy var skyboxRenderPipelineUntextured:MTLRenderPipelineState = {
        let desc = MTLRenderPipelineDescriptor()
        desc.colorAttachments[0].pixelFormat = .RGBA8Unorm;
        desc.colorAttachments[1].pixelFormat = .RGBA16Float;
        desc.colorAttachments[2].pixelFormat = .RGBA16Float;
        desc.depthAttachmentPixelFormat      = .Depth32Float;
        desc.sampleCount = 1
        desc.label = "Skybox Render"
        desc.vertexFunction = HgRenderer.library.newFunctionWithName("skyboxVert")
        desc.fragmentFunction = HgRenderer.library.newFunctionWithName("skyboxFragUntextured")
        var state:MTLRenderPipelineState
        do {
            try state = HgRenderer.device.newRenderPipelineStateWithDescriptor(desc)
        } catch let error {
            fatalError("Failed to create skybox pipeline state, error \(error)")
        }
        return state
    }()


    private lazy var gBufferRenderPipeline:MTLRenderPipelineState = {
        let desc = MTLRenderPipelineDescriptor()
        desc.colorAttachments[0].pixelFormat = .RGBA8Unorm;
        desc.colorAttachments[1].pixelFormat = .RGBA16Float;
        desc.colorAttachments[2].pixelFormat = .RGBA16Float;
        desc.depthAttachmentPixelFormat      = .Depth32Float;
        desc.sampleCount = 1
        desc.label = "gBuffer Render"
        desc.vertexFunction = HgRenderer.library.newFunctionWithName("gBufferVert")
        desc.fragmentFunction = HgRenderer.library.newFunctionWithName("gBufferFrag")
        var state:MTLRenderPipelineState
        do {
            try state = HgRenderer.device.newRenderPipelineStateWithDescriptor(desc)
            
        } catch let error {
            fatalError("Failed to create gBuffer pipeline state, error \(error)")
        }
        return state
    }()
    
    private lazy var lightBufferRenderPipeline:MTLRenderPipelineState = {
        let desc = MTLRenderPipelineDescriptor()
        
        let color = desc.colorAttachments[0]
        color.blendingEnabled = true
        color.rgbBlendOperation = .Add
        color.alphaBlendOperation = .Add
        color.pixelFormat = .BGRA8Unorm
        color.sourceRGBBlendFactor = .One
        color.sourceAlphaBlendFactor = .One
        color.destinationAlphaBlendFactor = .One
        color.destinationRGBBlendFactor = .One

        desc.label = "light Pipeline"
        
        desc.vertexFunction = HgRenderer.library.newFunctionWithName("lightVert")
        desc.fragmentFunction = HgRenderer.library.newFunctionWithName("lightFrag")
        var state:MTLRenderPipelineState
        do {
            try state = HgRenderer.device.newRenderPipelineStateWithDescriptor(desc)
            
        } catch let error {
            fatalError("Failed to create light buffer pipeline state, error \(error)")
        }
        return state
    }()

    private lazy var compositionRenderPipeline:MTLRenderPipelineState = {
        let desc = MTLRenderPipelineDescriptor()
        desc.colorAttachments[0].pixelFormat = .BGRA8Unorm;
        desc.label = "Composition Render"
        desc.vertexFunction = HgRenderer.library.newFunctionWithName("compositionVert")
        desc.fragmentFunction = HgRenderer.library.newFunctionWithName("compositionFrag")
        desc.sampleCount = 1
        var state:MTLRenderPipelineState
        do {
            try state = HgRenderer.device.newRenderPipelineStateWithDescriptor(desc)
        } catch let error {
            fatalError("Failed to create gBuffer pipeline state, error \(error)")
        }
        return state
    }()
    
    private lazy var postRenderPipeline:MTLRenderPipelineState = {
        let desc = MTLRenderPipelineDescriptor()
        desc.colorAttachments[0].pixelFormat = .BGRA8Unorm;
        desc.depthAttachmentPixelFormat = .Depth32Float_Stencil8
        desc.stencilAttachmentPixelFormat = .Depth32Float_Stencil8

        desc.label = "Post Render"
        desc.vertexFunction = HgRenderer.library.newFunctionWithName("postVert")
        desc.fragmentFunction = HgRenderer.library.newFunctionWithName("postFrag")
        desc.sampleCount = 1
        var state:MTLRenderPipelineState
        do {
            try state = HgRenderer.device.newRenderPipelineStateWithDescriptor(desc)
        } catch let error {
            fatalError("Failed to create gBuffer pipeline state, error \(error)")
        }
        return state
    }()
    
    private lazy var spriteRenderPipeline:MTLRenderPipelineState = {
        let desc = MTLRenderPipelineDescriptor()
        desc.label = "Fairy Render"
        desc.vertexFunction = HgRenderer.library.newFunctionWithName("fairyVert")
        desc.fragmentFunction = HgRenderer.library.newFunctionWithName("fairyFrag")
        var state:MTLRenderPipelineState
        do {
            try state = HgRenderer.device.newRenderPipelineStateWithDescriptor(desc)
        } catch let error {
            fatalError("Failed to create gBuffer pipeline state, error \(error)")
        }
        return state
    }()

    private lazy var shadowRenderPipeline:MTLRenderPipelineState = {
        let desc = MTLRenderPipelineDescriptor()
        desc.label = "Shadow Render Pipeleine"
        desc.vertexFunction = HgRenderer.library.newFunctionWithName("zOnly")
        desc.fragmentFunction = nil
        desc.depthAttachmentPixelFormat = HgRenderer.sharedInstance.zBufferTexture.pixelFormat
        var state:MTLRenderPipelineState
        do {
            try state = HgRenderer.device.newRenderPipelineStateWithDescriptor(desc)
        } catch let error {
            fatalError("Failed to create pipeline state, error \(error)")
        }
        return state
    }()
    
    
   
}


