//
//  HgMetalUtilities.swift
//  Mercury
//
//  Created by Joshua Knapp on 12/26/15.
//
//  Mostly swift ports of Apple MetalDeferredLighting code

import Foundation
import AppKit
import ModelIO
import MetalKit
import Quartz

struct ImageInfo
{
    let width:UInt
    let height:UInt
    let bitsPerPixel:UInt
    let hasAlpha:Bool
    let bitmapData:UnsafePointer<()>
}




func loadCubeTextureWithName(name:[String]) -> MTLTexture? {
    print("trying to load cube tex")
    if let texInfo = createImageInfo(name) {
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

func createImageInfo(name:[String]) -> ImageInfo?{
    print("starting createImageInfo")
    //for an overview of unmanaged see http://nshipster.com/unmanaged/
    //if let mdltex = MDLTexture(cubeWithImagesNamed: name){
    let mdltex = MDLSkyCubeTexture(name: nil,
                    channelEncoding: .UInt8,
                    textureDimensions: [Int32(128), Int32(128)],
                    turbidity: 0,
                    sunElevation: 1,
                    upperAtmosphereScattering: 0.5,
                    groundAlbedo: 0.2)
        mdltex.groundColor = CGColorCreateGenericRGB(0,0.0,0,1)
        print("made mdltex")
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






