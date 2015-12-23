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
    
    //Setup Globals constants
    private let _sunColor = (1.0, 0.875, 0.75)
    private let _clear_color = (0.0, 0.0, 0.0, 1.0)
    private let _albedo_clear_color = (0.75 + 0.075, 0.875 * 0.75 + 0.075, 0.75 * 0.75 + 0.075, 1.0)
    private let _light_buffer_clear_color = (0.1, 0.1, 0.125, 0.0)
    
    // Clear linear depth buffer to far plane in eye-space (25)
    private let _linear_depth_clear_color = (25.0, 25.0, 25.0, 25.0)

    //MARK: Textures
    private lazy var zBufferTexture: MTLTexture = self.makeZBufferTexture()
    private lazy var gBufferAlbedoTexture: MTLTexture = self.makeGBufferAlbedoTexture()
    private lazy var gBufferNormalTexture: MTLTexture = self.makeGBufferNormalTexture()
    private lazy var gBufferDepthTexture: MTLTexture = self.makeGBufferDepthTexture()
    private lazy var lightBufferTexture: MTLTexture = self.makeLightBufferTexture()
    private lazy var lightBufferDepthTexture: MTLTexture = self.makeLightBufferDepthTexture()
    
    //MARK: Render pass Descriptors
    private lazy var shadowRenderPassDescriptor: MTLRenderPassDescriptor = self.makeShadowRenderPassDescriptor()
    private lazy var gBufferRenderPassDescriptor: MTLRenderPassDescriptor = self.makeGBufferRenderPassDescriptor()
    private lazy var lightBufferRenderPassDescriptor: MTLRenderPassDescriptor = self.makeLightBufferRenderPassDescriptor()
    
    //MARK: Pipelines
    private lazy var skyboxRenderPipeline:MTLRenderPipelineState = self.makeSkyboxRenderPipeline()
    private lazy var gBufferRenderPipeline:MTLRenderPipelineState = self.makeGBufferRenderPipeline()
    private lazy var lightMaskRenderPipeline:MTLRenderPipelineState = self.makeLightMaskRenderPipeline()
    private lazy var lightBufferRenderPipeline:MTLRenderPipelineState = self.makeLightBufferRenderPipeline()
    private lazy var compositionRenderPipeline:MTLRenderPipelineState = self.makeCompositionRenderPipeline()
    private lazy var spriteRenderPipeline:MTLRenderPipelineState = self.makeSpriteRenderPipeline()
    private lazy var shadowRenderPipeline:MTLRenderPipelineState = self.makeShadowRenderPipeline()
    
    //MARK: DepthStencil States
    private lazy var noDepthStencilState:MTLDepthStencilState = self.makeNoDepthStencilState()
    private lazy var shadowDepthStencilState:MTLDepthStencilState = self.makeShadowDepthStencilState()
    private lazy var gBufferDepthStencilState:MTLDepthStencilState = self.makeGBufferDepthStencilState()
    private lazy var lightBufferDepthStencilState:MTLDepthStencilState = self.makeLightBufferDepthStencilState()
    private lazy var lightColorDepthStencilState:MTLDepthStencilState = self.makeLightColorDepthStencilState()
    private lazy var colorNoDepthStencilState:MTLDepthStencilState = self.makeColorNoDepthStencilState()
    private lazy var compositeDepthStencilState:MTLDepthStencilState = self.makeCompositeDepthStencilState()
    //private lazy var colorDepthStencilState:MTLDepthStencilState = self.makeColorDepthStencilState()
    
    private lazy var standardSampler:MTLSamplerState = self.makeStandardSampler()
    
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
            view!.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0)
            print("set view clear color")
        }
        
    }

//MARK:- Rendering
    func renderShadowBuffer(nodes nodes:[HgNode]) {
        
    }
    
    func renderGBuffer(nodes nodes:[HgNode], commandBuffer:MTLCommandBuffer) {
       
        let encoder = commandBuffer.renderCommandEncoderWithDescriptor(gBufferRenderPassDescriptor)
        encoder.label = "gBufferEncoder"
        encoder.setDepthStencilState(gBufferDepthStencilState)
        encoder.pushDebugGroup("gBuffer")
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
        encoder.setDepthStencilState(lightBufferDepthStencilState)
        encoder.pushDebugGroup("lightBuffer")
        encoder.setRenderPipelineState(lightBufferRenderPipeline)
        
        encoder.setFragmentTexture(gBufferNormalTexture, atIndex: 0)
        
        for node in lights {
            guard node.vertexCount > 0 else { continue }
            encoder.setVertexBuffer(node.vertexBuffer, offset: 0, atIndex: 0)
            encoder.setVertexBuffer(node.uniformBuffer, offset: 0, atIndex: 1)
            encoder.setFragmentBuffer(node.lightDataBuffer, offset: 0, atIndex: 0)
            //encoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: 12)
            encoder.drawIndexedPrimitives(.Triangle, indexCount: 60, indexType: .UInt16 , indexBuffer: node.indexBuffer, indexBufferOffset: 0)
        }
        encoder.popDebugGroup()
        encoder.endEncoding()
    }
    
    func render(nodes nodes:[HgNode], lights:[HgLightNode]){
    
        guard let v = HgRenderer.sharedInstance.view else {print("could not get view"); return}
        guard let renderPassDescriptor = v.currentRenderPassDescriptor else { print("could not get rpd");return }
        
        //dispatch_semaphore_wait(inflightSemaphore, DISPATCH_TIME_FOREVER)
        
        let commandBuffer = HgRenderer.commandQueue.commandBuffer()
        
        // 1st pass (shadow depth texture pass)
        renderShadowBuffer(nodes: nodes)
        
        // 2nd pass (gbuffer)
        renderGBuffer(nodes:nodes, commandBuffer: commandBuffer)
        renderLightBuffer(lights:lights, commandBuffer: commandBuffer)
        
        
        //combine textures in full screen quad
        //renderPassDescriptor.colorAttachments[1].texture = lightBufferTexture
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
    
    private func makeLightBufferDepthTexture() -> MTLTexture {
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
        desc.depthAttachment.loadAction = .Clear;
        desc.depthAttachment.storeAction = .DontCare
        desc.depthAttachment.texture = lightBufferDepthTexture
        desc.depthAttachment.clearDepth = 1.0
        return desc
    }
    
    private func makeMainRenderPassDescriptor() -> MTLRenderPassDescriptor {
        let descriptor = MTLRenderPassDescriptor()
        
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: _albedo_clear_color.0, green: _albedo_clear_color.1, blue: _albedo_clear_color.2, alpha: _albedo_clear_color.3)
        descriptor.colorAttachments[1].clearColor = MTLClearColor(red: _clear_color.0, green: _clear_color.1, blue: _clear_color.2, alpha: _clear_color.3)
        descriptor.colorAttachments[2].clearColor = MTLClearColor(red: _linear_depth_clear_color.0, green: _linear_depth_clear_color.1, blue: _linear_depth_clear_color.2, alpha: _linear_depth_clear_color.3)
        descriptor.colorAttachments[3].clearColor = MTLClearColor(red: _light_buffer_clear_color.0, green: _light_buffer_clear_color.1, blue: _light_buffer_clear_color.2, alpha: _light_buffer_clear_color.3)
        
        descriptor.depthAttachment.clearDepth = 1.0
        descriptor.stencilAttachment.clearStencil = 0

        return descriptor
    }
    
    //MARK: Pipeline Constructors
    private lazy var baseRenderPipelineDescriptor: MTLRenderPipelineDescriptor = {
        let desc = MTLRenderPipelineDescriptor()
        desc.label = "Main Render Pipeline"
        desc.depthAttachmentPixelFormat = .Depth32Float_Stencil8
        desc.stencilAttachmentPixelFormat = .Depth32Float_Stencil8
        desc.colorAttachments[0].pixelFormat = .BGRA8Unorm;
        //desc.colorAttachments[1].pixelFormat = .BGRA8Unorm;
        desc.depthAttachmentPixelFormat      = .Depth32Float_Stencil8
        return desc
    }()
    
    private func makeSkyboxRenderPipeline() -> MTLRenderPipelineState {
        let desc = baseRenderPipelineDescriptor
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
    
    private func makeLightMaskRenderPipeline() -> MTLRenderPipelineState {
        let desc = baseRenderPipelineDescriptor
        desc.label = "Light Mask Render"
        desc.vertexFunction = HgRenderer.library.newFunctionWithName("lightVert")
        desc.fragmentFunction = nil
        //Have active rendertargets but don't want to write to color
        //setup a blendsetate with no color writes for light mask pipeline
        for i in 0..<4 {
            desc.colorAttachments[i].writeMask = .None
        }
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
        desc.depthAttachmentPixelFormat = .Depth32Float
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
        let desc = baseRenderPipelineDescriptor
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
        let desc = baseRenderPipelineDescriptor
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
    private lazy var baseDepthStencilDescriptor = MTLDepthStencilDescriptor()
    private lazy var stencilState = MTLStencilDescriptor()
    
    private func makeNoDepthStencilState() -> MTLDepthStencilState {
        let desc = baseDepthStencilDescriptor
        desc.depthWriteEnabled = false
        desc.depthCompareFunction = .Always
        return HgRenderer.device.newDepthStencilStateWithDescriptor(desc)
    }

    private func makeShadowDepthStencilState() -> MTLDepthStencilState {
        let desc = baseDepthStencilDescriptor
        desc.depthWriteEnabled = true
        desc.depthCompareFunction = .LessEqual
        return HgRenderer.device.newDepthStencilStateWithDescriptor(desc)
    }
    
    private func makeGBufferDepthStencilState() -> MTLDepthStencilState {
        let desc = baseDepthStencilDescriptor
        /*
        let stenc = stencilState
        stenc.stencilCompareFunction = .Always
        stenc.stencilFailureOperation = .Keep
        stenc.depthFailureOperation = .Keep
        stenc.depthStencilPassOperation = .Replace
        stenc.readMask = 0xFF
        stenc.writeMask = 0xFF
*/
        desc.depthWriteEnabled = true
        desc.depthCompareFunction = .Less
        //desc.frontFaceStencil = stenc
        //desc.backFaceStencil = stenc
        return HgRenderer.device.newDepthStencilStateWithDescriptor(desc)
    }
    
    private func makeLightBufferDepthStencilState() -> MTLDepthStencilState {
        let desc = baseDepthStencilDescriptor
        /*
        let stenc = stencilState
        stenc.stencilCompareFunction = .Always
        stenc.stencilFailureOperation = .Keep
        stenc.depthFailureOperation = .Keep
        stenc.depthStencilPassOperation = .Replace
        stenc.readMask = 0xFF
        stenc.writeMask = 0xFF
        */
        desc.depthWriteEnabled = true
        desc.depthCompareFunction = .Always
        //desc.frontFaceStencil = stenc
        //desc.backFaceStencil = stenc
        return HgRenderer.device.newDepthStencilStateWithDescriptor(desc)
    }
    
    private func makeLightColorDepthStencilState() -> MTLDepthStencilState {
        let desc = baseDepthStencilDescriptor
        let stenc = stencilState
        desc.depthWriteEnabled = false
        stenc.stencilCompareFunction = .Less
        stenc.stencilFailureOperation = .Keep
        stenc.depthFailureOperation = .DecrementClamp
        stenc.depthStencilPassOperation = .DecrementClamp
        stenc.readMask = 0xFF
        stenc.writeMask = 0xFF
        desc.depthCompareFunction = .LessEqual
        desc.frontFaceStencil = stenc
        desc.backFaceStencil = stenc
        return HgRenderer.device.newDepthStencilStateWithDescriptor(desc)
    }

    private func makeColorNoDepthStencilState() -> MTLDepthStencilState {
        let desc = baseDepthStencilDescriptor
        let stenc = stencilState
        desc.depthWriteEnabled = false
        stenc.stencilCompareFunction = .Less
        stenc.stencilFailureOperation = .Keep
        stenc.depthFailureOperation = .DecrementClamp
        stenc.depthStencilPassOperation = .DecrementClamp
        stenc.readMask = 0xFF
        stenc.writeMask = 0xFF
        desc.depthCompareFunction = .Always
        desc.frontFaceStencil = stenc
        desc.backFaceStencil = stenc
        return HgRenderer.device.newDepthStencilStateWithDescriptor(desc)
    }

    private func makeCompositeDepthStencilState() -> MTLDepthStencilState {
        let desc = baseDepthStencilDescriptor
        //let stenc = stencilState
        desc.depthWriteEnabled = false
        /*
        stenc.stencilCompareFunction = .Equal
        stenc.stencilFailureOperation = .Keep
        stenc.depthFailureOperation = .Keep
        stenc.depthStencilPassOperation = .Keep
        stenc.readMask = 0xFF
        stenc.writeMask = 0
*/
        desc.depthCompareFunction = .Always
        //desc.frontFaceStencil = stenc
        //desc.backFaceStencil = stenc
        return HgRenderer.device.newDepthStencilStateWithDescriptor(desc)
    }

    /*
    private func makeColorDepthStencilState() -> MTLDepthStencilState {
        let desc = MTLDepthStencilDescriptor()
        desc.depthWriteEnabled = true
        desc.depthCompareFunction = .LessEqual
        return HgRenderer.device.newDepthStencilStateWithDescriptor(desc)
    }*/
    
    private func makeStandardSampler() -> MTLSamplerState {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = MTLSamplerMinMagFilter.Nearest
        samplerDescriptor.magFilter = MTLSamplerMinMagFilter.Linear
        samplerDescriptor.sAddressMode = .ClampToEdge
        samplerDescriptor.tAddressMode = .ClampToEdge
        samplerDescriptor.maxAnisotropy = 16
        samplerDescriptor.normalizedCoordinates = true
        let r = HgRenderer.device.newSamplerStateWithDescriptor(samplerDescriptor)
        return r
    }

}


