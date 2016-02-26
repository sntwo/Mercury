
//
//  HgSceneNode.swift
//  mercury
//
//  Created by Joshua Knapp on 2/20/15.
//  Copyright (c) 2015 Joshua Knapp. All rights reserved.
//

import GLKit
import MetalKit
import simd

protocol HgViewController:class { }

class HgScene: HgNode {
    
    //private(set) var lights = [HgLightNode]()
    private(set) var skybox = HgSkyboxNode(size:1000)
    
    var projectionMatrix = float4x4(1)
    var projectionMatrixIsDirty = true
    
    var sunPosition = float3(0,0,1)
    private(set) var lightPosition = float3(0,0.5,-1)
    
    override var scene:HgScene { get { return self } } // scene doesn't have a scene
    override var parent:HgNode? { get { return nil } set {} } // scene doesn't have a parent
    
    
    override var modelMatrixIsDirty: Bool{
        didSet {
            for child in children {
                child.modelMatrixIsDirty = true
            }
            
            skybox.modelMatrixIsDirty = true
        }
    }
    
    weak var view:MTKView?

    var magnification:Float = 1 { didSet { modelMatrixIsDirty = true } }
    /// below this value shadows will not be shown
    var minMagnificationForShadows:Float = 0.5
    weak var controller:HgViewController?
    
    ///run is the place to load custom content into the scene graph
    func run(){
        
    }
    
    func userSelection(){
        
    }
    
    init(view:MTKView){
        self.view = view
        super.init()
        skybox.parent = self
    }
    
    func render()  {
    
        

        
        super.updateNode(1/60)
        
        updateProjectionMatrix()
       /*
        for light in lights{
            light.updateNode(1/60)
        }
        */
        skybox.updateNode(1/60)
            
        let (n, l) = flattenHeirarchy()
        HgRenderer.sharedInstance.render(nodes:n, lights:l, box:skybox)
        
        
    }
    
    func confirmAction(){
        print("action confirmed")
    }
    
    func denyAction(){
        print("action denied")
    }
        
    func updateProjectionMatrix(){
        
        guard let view = view else { return }
    
        let w = Float(view.frame.size.width)
        let h = Float(view.frame.size.height)
        
        let persp = float4x4(perspectiveWithFOVY: 140, aspect: 1, near:0.01, far: 1)
        
        projectionMatrix = float4x4(orthoWithLeft: -w / 2 / magnification, right: w / 2 / magnification, bottom: -h / 2 / magnification, top: h / 2 / magnification, nearZ: 5280 * 2, farZ: -5280 * 2)
        
        //lightMatrix =  projectionMatrix * float4x4(lookAtFromEyeX: position.x, eyeY: position.y, eyeZ: 0, centerX: lightPosition.x, centerY: lightPosition.y, centerZ:lightPosition.z, upX: 0, upY: 0, upZ: 1)
        
        projectionMatrix = persp * projectionMatrix
        
        projectionMatrixIsDirty = false
    }

    
    override func updateModelMatrix(){
        
        let x = float4x4(XRotation: rotation.x)
        let y = float4x4(YRotation: rotation.y)
        let z = float4x4(ZRotation: rotation.z)
        let t = float4x4(translation: position)
        let s = float4x4(scale: scale)
        modelMatrix = x * y * z * t * s

        modelMatrixIsDirty = false
        
    }

    
    

}



