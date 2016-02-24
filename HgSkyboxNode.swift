//
//  File.swift
//  Mercury
//
//  Created by Joshua Knapp on 12/24/15.
//
//

import Foundation
import simd
import Metal
import ModelIO

class HgSkyboxNode:HgNode {
    
    var texture:MTLTexture?
    
    
    init(size:Int) {
    
        super.init()
        
        let s = Float(1)//Float(size / 2)
        
        vertexData = Array(count: 36, repeatedValue: vertex())
        
        //top face
        vertexData[0].position = ( s,     s,      s)
        vertexData[1].position = ( -s,       s,      s)
        vertexData[2].position = ( -s,      -s,     s)
        vertexData[3].position = vertexData[2].position
        vertexData[4].position = ( s,       -s,     s)
        vertexData[5].position = vertexData[0].position
        
        for i in 0..<6 {
            vertexData[i].normal = (0,0,-1)
            vertexData[i].ambientColor = (0,1,1,1)
            vertexData[i].diffuseColor = (1,0,1,1)
        }
        
        //bottom face
        vertexData[6].position = ( -s,     s,      -s)
        vertexData[7].position = ( s,       s,      -s)
        vertexData[8].position = ( s,      -s,     -s)
        vertexData[9].position = vertexData[8].position
        vertexData[10].position = ( -s,       -s,     -s)
        vertexData[11].position = vertexData[6].position
        
        for i in 6..<12 {
            vertexData[i].normal = (0,0,1)
            vertexData[i].ambientColor = (0,1,1,1)
            vertexData[i].diffuseColor = (1,0,1,1)
        }
        
        //north face
        vertexData[12].position = ( -s,     s,      s)
        vertexData[13].position = ( s,       s,      s)
        vertexData[14].position = ( s,      s,     -s)
        vertexData[15].position = vertexData[14].position
        vertexData[16].position = ( -s,       s,     -s)
        vertexData[17].position = vertexData[12].position
        
        for i in 12..<18 {
            vertexData[i].normal = (0,-1,0)
            vertexData[i].ambientColor = (0,1,1,1)
            vertexData[i].diffuseColor = (1,0,1,1)
        }
        
        //south face
        vertexData[18].position = ( s,     -s,      s)
        vertexData[19].position = ( -s,       -s,      s)
        vertexData[20].position = ( -s,      -s,     -s)
        vertexData[21].position = vertexData[20].position
        vertexData[22].position = ( s,       -s,     -s)
        vertexData[23].position = vertexData[18].position
        
        for i in 18..<24 {
            vertexData[i].normal = (0,1,0)
            vertexData[i].ambientColor = (0,1,1,1)
            vertexData[i].diffuseColor = (1,0,1,1)
        }
        
        //east face
        vertexData[24].position = ( s,     s,      s)
        vertexData[25].position = ( s,       -s,      s)
        vertexData[26].position = ( s,      -s,     -s)
        vertexData[27].position = vertexData[26].position
        vertexData[28].position = ( s,       s,     -s)
        vertexData[29].position = vertexData[24].position
        
        for i in 24..<30 {
            vertexData[i].normal = (-1,0,0)
            vertexData[i].ambientColor = (0,1,1,1)
            vertexData[i].diffuseColor = (1,0,1,1)
        }
        
        //west face
        vertexData[30].position = ( -s,     -s,      s)
        vertexData[31].position = ( -s,       s,      s)
        vertexData[32].position = ( -s,      s,     -s)
        vertexData[33].position = vertexData[32].position
        vertexData[34].position = ( -s,       -s,     -s)
        vertexData[35].position = vertexData[30].position
        
        for i in 30..<36 {
            vertexData[i].normal = (1,0,0)
            vertexData[i].ambientColor = (0,1,1,1)
            vertexData[i].diffuseColor = (1,0,1,1)
        }

        vertexCount = 36
        
        //self.scale = float3(Float(size),Float(size),Float(size))
        
        self.updateVertexBuffer()
    }

    override func updateModelMatrix(){
        
        
        if let p = self.parent {
            //give a slight amount of parralax with skybox... this could potentially scroll off screen right now
            self.position = float3(0, 0, -p.position.z)
            //...found this relationship empirically
            self.rotation = float3(p.rotation.x + Float(M_PI_2), p.rotation.z, p.rotation.y)
        }
        
        let x = float4x4(XRotation: rotation.x)
        let y = float4x4(YRotation: rotation.y)
        let z = float4x4(ZRotation: rotation.z)
        let t = float4x4(translation: position)
        let s = float4x4(scale: scale)
        let m = t * s * x * y * z
    
        modelMatrix = m
        modelMatrixIsDirty = false
        
    }
    
    struct ImageInfo
    {
        let width:UInt
        let height:UInt
        let bitsPerPixel:UInt
        let hasAlpha:Bool
        let bitmapData:UnsafePointer<()>
    }
    
    class func loadCubeTextureWithMDLTexture(tex:MDLTexture) -> MTLTexture? {
        print("trying to load cube tex")
        if let texInfo = HgSkyboxNode.createImageInfoFromMDLTexture(tex) {
            print("made texinfo")
            if texInfo.bitmapData == nil { return nil }
            
            if texInfo.hasAlpha == false {
                print("ERROR: loadCubeTexture requires an alpha channel"); return nil
            }
            
            let Npixels = Int(texInfo.width * texInfo.width)
            let descriptor = MTLTextureDescriptor.textureCubeDescriptorWithPixelFormat(.RGBA8Unorm, size: Int(texInfo.width), mipmapped: false)
            let texture = HgRenderer.device.newTextureWithDescriptor(descriptor)
            
            var i = 0
            let region = MTLRegionMake2D(0, 0, Int(texInfo.width), Int(texInfo.width))
            while i < 6 {
                texture.replaceRegion(region, mipmapLevel: 0, slice: i, withBytes: texInfo.bitmapData + i * Npixels * 4, bytesPerRow: 4 * Int(texInfo.width), bytesPerImage: Npixels * 4)
                i += 1
            }
            print("made texture of type \(texture.textureType)")
            return texture
        }
        return nil
    }
    
    class func createImageInfoFromMDLTexture(mdltex:MDLTexture) -> ImageInfo?{
        print("starting createImageInfo")
        //for an overview of unmanaged see http://nshipster.com/unmanaged/
        
        if let unmanagedCGImage = mdltex.imageFromTexture(){
            print("made mdltexture and unmanaged image")
            let image = unmanagedCGImage.takeUnretainedValue()
            
            
            let width = Int(CGImageGetWidth(image))
            let height = Int(CGImageGetHeight(image))
            
            print("texture is \(width) x \(height)")
            if height / 6 == width { print("texure appears to be 1 x 6")}
            
            let bitsPerPixel = Int(CGImageGetBitsPerPixel(image))
            let hasAlpha = CGImageGetAlphaInfo(image) != .None
            let sizeInBytes = Int(width * height * bitsPerPixel / 8)
            let bytesPerRow = width * bitsPerPixel / 8
            
            let bitmapData = malloc(sizeInBytes)
            let context = CGBitmapContextCreate(bitmapData, width, height, 8, bytesPerRow, CGImageGetColorSpace(image), CGImageGetBitmapInfo(image).rawValue)
            
            
            CGContextDrawImage(context, CGRect(x: 0,y: 0,width: width, height: height), image)
            
            return ImageInfo(width: UInt(width), height: UInt(height), bitsPerPixel: UInt(bitsPerPixel), hasAlpha: hasAlpha, bitmapData: bitmapData)
        }
            
        else {
            print("could not make mdltex")
        }
        
        return nil
        
    }

    
    
}