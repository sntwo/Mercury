//
//  HgRenderer.swift
//  mercury
//
//  Created by Joshua Knapp on 11/10/15.
//  Copyright © 2015 Joshua Knapp. All rights reserved.
//

import Foundation
import MetalKit

struct SunData {
    var direction:float4 = float4(0,0,0,0)
    var color:float4 = float4(1.0, 0.875, 0.75, 1)
}

private let MaxBuffers = 3

final class HgRenderer {
    
    struct quadVertex {
        var position: (x:Float, y:Float) = (0, 0)
        var texture: (u:Float, v:Float) = (0, 0)
    }
    ////////////////////////singleton syntax
    static let sharedInstance = HgRenderer()
    private init(){}
    ////////////////////////////////////////
    
    static let device: MTLDevice = MTLCreateSystemDefaultDevice()!
    static let library = device.newDefaultLibrary()!
    static let commandQueue = device.newCommandQueue()
    
    private let inflightSemaphore = dispatch_semaphore_create(MaxBuffers)
    private var bufferIndex = 0
    
    //MARK: Textures
    private lazy var zBufferTexture: MTLTexture = self.makeZBufferTexture()
    private lazy var gBufferAlbedoTexture: MTLTexture = self.makeGBufferAlbedoTexture()
    private lazy var gBufferModelPositionTexture: MTLTexture = self.makeGBufferModelPositionTexture()
    private lazy var gBufferNormalTexture: MTLTexture = self.makeGBufferNormalTexture()
    private lazy var gBufferDepthTexture: MTLTexture = self.makeGBufferDepthTexture()
    private lazy var lightBufferTexture: MTLTexture = self.makeLightBufferTexture()
    //private lazy var skyboxTexture: MTLTexture = { return loadCubeTextureWithName(["TropicalSunnyDayBack2048.png","TropicalSunnyDayDown2048.png","TropicalSunnyDayFront2048.png","TropicalSunnyDayLeft2048.png","TropicalSunnyDayRight2048.png","TropicalSunnyDayUp2048.png" ])! }()
    private lazy var skyboxTexture: MTLTexture = { return loadCubeTextureWithName(["skybox"])! }()
    
    //MARK: Render pass Descriptors
    private lazy var shadowRenderPassDescriptor: MTLRenderPassDescriptor = self.makeShadowRenderPassDescriptor()
    private lazy var gBufferRenderPassDescriptor: MTLRenderPassDescriptor = self.makeGBufferRenderPassDescriptor()
    private lazy var lightBufferRenderPassDescriptor: MTLRenderPassDescriptor = self.makeLightBufferRenderPassDescriptor()
    
    //MARK: Pipelines
    private lazy var skyboxRenderPipeline:MTLRenderPipelineState = self.makeSkyboxRenderPipeline()
    private lazy var gBufferRenderPipeline:MTLRenderPipelineState = self.makeGBufferRenderPipeline()
    private lazy var lightBufferRenderPipeline:MTLRenderPipelineState = self.makeLightBufferRenderPipeline()
    private lazy var compositionRenderPipeline:MTLRenderPipelineState = self.makeCompositionRenderPipeline()
    private lazy var spriteRenderPipeline:MTLRenderPipelineState = self.makeSpriteRenderPipeline()
    private lazy var shadowRenderPipeline:MTLRenderPipelineState = self.makeShadowRenderPipeline()
    
    //MARK: DepthStencil States
    private lazy var shadowDepthStencilState:MTLDepthStencilState = self.makeShadowDepthStencilState()
    private lazy var gBufferDepthStencilState:MTLDepthStencilState = self.makeGBufferDepthStencilState()
    private lazy var compositeDepthStencilState:MTLDepthStencilState = self.makeCompositeDepthStencilState()
    
    lazy var quadVertexBuffer:MTLBuffer = {
        var quadVerts = Array(count: 6, repeatedValue: quadVertex())
        quadVerts[0].position = (-1,1) // top left
        quadVerts[0].texture = (0,1)
        quadVerts[1].position = (1,1)  // top right
        quadVerts[1].texture = (1,1)
        quadVerts[2].position = (1,-1)  // bottom right
        quadVerts[2].texture = (1,0)
        quadVerts[3] = quadVerts[0]
        quadVerts[4] = quadVerts[2]
        quadVerts[5].position = (-1,-1) // bottom left
        quadVerts[5].texture = (0,0)

        return HgRenderer.device.newBufferWithBytes(quadVerts,length:sizeof(Float) * 24,options:[])
    }()
    
    var view:MTKView? = nil {
        
        didSet {
            view!.depthStencilPixelFormat = .Depth32Float_Stencil8
            view!.colorPixelFormat = .BGRA8Unorm
            view!.sampleCount = 1
            view!.clearColor = MTLClearColorMake(0.8, 0.8, 0.8, 1.0)
        }
        
    }

//MARK:- Rendering
    func renderShadowBuffer(nodes nodes:[HgNode]) {
        
    }
    
    func renderGBuffer(nodes nodes:[HgNode], box:HgSkyboxNode, commandBuffer:MTLCommandBuffer) {
       
        let encoder = commandBuffer.renderCommandEncoderWithDescriptor(gBufferRenderPassDescriptor)
        
        encoder.setDepthStencilState(gBufferDepthStencilState)
        encoder.setCullMode(.Back)
        
        //encoder.pushDebugGroup("skybox")
        encoder.setRenderPipelineState(skyboxRenderPipeline)
        encoder.setVertexBuffer(box.vertexBuffer, offset: 0, atIndex: 0)
        encoder.setVertexBuffer(box.uniformBuffer, offset: 0, atIndex: 1)
        encoder.setFragmentTexture(skyboxTexture, atIndex: 0)
    
        encoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: box.vertexCount)
        
        //encoder.popDebugGroup()

        //encoder.label = "gBufferEncoder"
        
        //encoder.pushDebugGroup("gBuffer")
        
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
    
    func render(nodes nodes:[HgNode], lights:[HgLightNode], box:HgSkyboxNode){
    
        guard let v = HgRenderer.sharedInstance.view else {print("could not get view"); return}
        guard let renderPassDescriptor = v.currentRenderPassDescriptor else { print("could not get rpd");return }
    
        //dispatch_semaphore_wait(inflightSemaphore, DISPATCH_TIME_FOREVER)
        
        let commandBuffer = HgRenderer.commandQueue.commandBuffer()
        
        // 1st pass (shadow depth texture pass)
        renderShadowBuffer(nodes: nodes)
        
        // 2nd pass (gbuffer)
        renderGBuffer(nodes:nodes, box:box, commandBuffer: commandBuffer)
        renderLightBuffer(lights:lights, commandBuffer: commandBuffer)
        
        
        //combine textures in full screen quad
        let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
        renderEncoder.label = "quad"
        renderEncoder.setRenderPipelineState(compositionRenderPipeline)
        renderEncoder.setDepthStencilState(compositeDepthStencilState)
        renderEncoder.setVertexBuffer(quadVertexBuffer, offset: 0, atIndex: 0)
        renderEncoder.setFragmentTexture(gBufferAlbedoTexture, atIndex: 0)
        renderEncoder.setFragmentTexture(lightBufferTexture, atIndex: 1)
        renderEncoder.setFragmentTexture(gBufferNormalTexture, atIndex: 2)
        
        renderEncoder.drawPrimitives(.Triangle, vertexStart:0, vertexCount:6)
        renderEncoder.endEncoding()
        commandBuffer.presentDrawable(v.currentDrawable!)
        commandBuffer.commit()

    }
 


    //MARK:- Setup
    
    //Mark: Textures
    private func makeZBufferTexture() ->  MTLTexture  {
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        let x = Int(v.frame.size.width)
        let y = Int(v.frame.size.height)
        let zbufferTextureDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(MTLPixelFormat.Depth32Float, width: x, height: y, mipmapped: false)
        zbufferTextureDescriptor.usage = [.RenderTarget, .ShaderRead]
        zbufferTextureDescriptor.storageMode = .Private
        return HgRenderer.device.newTextureWithDescriptor(zbufferTextureDescriptor)
    }
    
    private func makeGBufferAlbedoTexture() -> MTLTexture {
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        let x = Int(v.frame.size.width)
        let y = Int(v.frame.size.height)

        let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.RGBA8Unorm, width: x, height: y, mipmapped: false)
        descriptor.sampleCount = 1
        descriptor.storageMode = .Private
        descriptor.textureType = .Type2D
        descriptor.usage = [.RenderTarget, .ShaderRead]
        
        return HgRenderer.device.newTextureWithDescriptor(descriptor)
    }
    
    private func makeGBufferNormalTexture() -> MTLTexture {
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        let x = Int(v.frame.size.width)
        let y = Int(v.frame.size.height)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.RGBA16Float, width: x, height: y, mipmapped: false)
        descriptor.sampleCount = 1
        descriptor.storageMode = .Private
        descriptor.textureType = .Type2D
        descriptor.usage = [.RenderTarget, .ShaderRead]
        
        return HgRenderer.device.newTextureWithDescriptor(descriptor)
    }
    
    private func makeGBufferModelPositionTexture() -> MTLTexture {
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        let x = Int(v.frame.size.width)
        let y = Int(v.frame.size.height)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.RGBA16Float, width: x, height: y, mipmapped: false)
        descriptor.sampleCount = 1
        descriptor.storageMode = .Private
        descriptor.textureType = .Type2D
        descriptor.usage = [.RenderTarget, .ShaderRead]
        
        return HgRenderer.device.newTextureWithDescriptor(descriptor)
    }
    
    private func makeLightBufferTexture() -> MTLTexture {
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        let x = Int(v.frame.size.width)
        let y = Int(v.frame.size.height)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.BGRA8Unorm, width: x, height: y, mipmapped: false)
        descriptor.sampleCount = 1
        descriptor.storageMode = .Private
        descriptor.textureType = .Type2D
        descriptor.usage = [.RenderTarget, .ShaderRead]
        
        return HgRenderer.device.newTextureWithDescriptor(descriptor)
    }
    
    private func makeGBufferDepthTexture() -> MTLTexture {
        guard let v = self.view else {fatalError("did not set viewWidth and viewHeight for renderer")}
        let x = Int(v.frame.size.width)
        let y = Int(v.frame.size.height)
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(.Depth32Float, width: x, height: y, mipmapped: false)
        descriptor.sampleCount = 1
        descriptor.storageMode = .Private
        descriptor.textureType = .Type2D
        descriptor.usage = [.RenderTarget, .ShaderRead]
        
        return HgRenderer.device.newTextureWithDescriptor(descriptor)
    }
    
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
    //MARK: Render pass descriptors
    private func makeShadowRenderPassDescriptor() -> MTLRenderPassDescriptor {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.depthAttachment.texture = HgRenderer.sharedInstance.zBufferTexture
        descriptor.depthAttachment.loadAction = .Clear;
        descriptor.depthAttachment.storeAction = .Store;
        descriptor.depthAttachment.clearDepth = 1.0
        return descriptor
    }
    
    private func makeGBufferRenderPassDescriptor() -> MTLRenderPassDescriptor {
        let desc = MTLRenderPassDescriptor()
        let color = desc.colorAttachments[0]
        color.clearColor = MTLClearColorMake(0,0,0,1)
        color.texture = gBufferAlbedoTexture
        color.loadAction = .Clear
        color.storeAction = .Store
        let color2 = desc.colorAttachments[1]
        color2.texture = gBufferNormalTexture
        color2.loadAction = .Clear
        color2.storeAction = .Store
        let color3 = desc.colorAttachments[2]
        color3.texture = gBufferModelPositionTexture
        color3.loadAction = .Clear
        color3.storeAction = .Store

        let depth = desc.depthAttachment
        depth.loadAction = .Clear
        depth.storeAction = .Store
        depth.texture = gBufferDepthTexture
        depth.clearDepth = 1.0
        return desc
    }
    
    private func makeLightBufferRenderPassDescriptor() -> MTLRenderPassDescriptor {
        let desc = MTLRenderPassDescriptor()
        let color = desc.colorAttachments[0]
        color.clearColor = MTLClearColorMake(0,0,0,1)
        color.texture = lightBufferTexture
        color.loadAction = .Clear
        color.storeAction = .Store
        return desc
    }
    
    //MARK: Pipeline Constructors
    private func makeSkyboxRenderPipeline() -> MTLRenderPipelineState {
        let desc = MTLRenderPipelineDescriptor()
        desc.colorAttachments[0].pixelFormat = .RGBA8Unorm;
        desc.colorAttachments[1].pixelFormat = .RGBA16Float;
        desc.colorAttachments[2].pixelFormat = .RGBA16Float;
        desc.depthAttachmentPixelFormat      = .Depth32Float;
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
    }

    private func makeGBufferRenderPipeline() -> MTLRenderPipelineState {
        let desc = MTLRenderPipelineDescriptor()
        desc.colorAttachments[0].pixelFormat = .RGBA8Unorm;
        desc.colorAttachments[1].pixelFormat = .RGBA16Float;
        desc.colorAttachments[2].pixelFormat = .RGBA16Float;
        desc.depthAttachmentPixelFormat      = .Depth32Float;
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
    }
    
    private func makeLightBufferRenderPipeline() -> MTLRenderPipelineState {
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
    }

    private func makeCompositionRenderPipeline() -> MTLRenderPipelineState {
        let desc = MTLRenderPipelineDescriptor()
        desc.colorAttachments[0].pixelFormat = .BGRA8Unorm;
        desc.depthAttachmentPixelFormat = .Depth32Float_Stencil8
        desc.stencilAttachmentPixelFormat = .Depth32Float_Stencil8
        desc.label = "Composition Render"
        desc.vertexFunction = HgRenderer.library.newFunctionWithName("compositionVert")
        desc.fragmentFunction = HgRenderer.library.newFunctionWithName("compositionFrag")
        var state:MTLRenderPipelineState
        do {
            try state = HgRenderer.device.newRenderPipelineStateWithDescriptor(desc)
        } catch let error {
            fatalError("Failed to create gBuffer pipeline state, error \(error)")
        }
        return state
    }
    
    private func makeSpriteRenderPipeline() -> MTLRenderPipelineState {
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
    }

    private func makeShadowRenderPipeline() -> MTLRenderPipelineState {
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
    }
    
    //MARK: Depth and stencil constructors
    private func makeShadowDepthStencilState() -> MTLDepthStencilState {
        let desc = MTLDepthStencilDescriptor()
        desc.depthWriteEnabled = true
        desc.depthCompareFunction = .LessEqual
        return HgRenderer.device.newDepthStencilStateWithDescriptor(desc)
    }
    
    private func makeGBufferDepthStencilState() -> MTLDepthStencilState {
        let desc = MTLDepthStencilDescriptor()
        desc.depthWriteEnabled = true
        desc.depthCompareFunction = .LessEqual
        return HgRenderer.device.newDepthStencilStateWithDescriptor(desc)
    }

    private func makeCompositeDepthStencilState() -> MTLDepthStencilState {
        let desc = MTLDepthStencilDescriptor()
        desc.depthWriteEnabled = false
        desc.depthCompareFunction = .Always
        return HgRenderer.device.newDepthStencilStateWithDescriptor(desc)
    }

   
}


