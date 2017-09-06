//
//  HgOSXViewController.swift
//  mercury
//
//  Created by Joshua Knapp on 8/1/15.
//  Copyright © 2015 Joshua Knapp. All rights reserved.
//


import MetalKit

class HgOSXViewController: NSViewController, MTKViewDelegate {
    
    //private let inflightSemaphore = dispatch_semaphore_create(MaxBuffers)
    
    fileprivate var bufferIndex = 0

    var currentScene: HgScene!
    
    var mouseLoc:NSPoint = NSPoint(x: 0,y: 0)
    var touchesLoc:NSPoint = NSPoint(x:0, y:0)
    var trackedTouch:NSTouch?
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // setup view properties
        let view = self.view as! MTKView
        view.delegate = self
        
        view.device = HgRenderer.device
        view.sampleCount = 1
        view.colorPixelFormat = MTLPixelFormat.bgra8Unorm
        self.view.acceptsTouchEvents = true
        
        HgRenderer.sharedInstance.view = view
        currentScene = HouseScene(view: view)
        //currentScene = CubeScene(view: view)
        
        currentScene.run()
    }

    //MARK: MTKViewDelegate Methods
    func draw(in view: MTKView) {
       
        if let cur = currentScene {
            cur.render()
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    override func touchesMoved(with event: NSEvent) {
        
        let touches = event.touches(matching: .moved, in: view)
        guard let touch = event.touches(matching: .moved, in: view).first else { return }
        
        switch touches.count {
        case 1:
            //print("1 touch moved")
            break
            
        case 2:  //rotate scene
            
                let p = touch.normalizedPosition
                defer { touchesLoc = p }
                
                let dy = Float(p.y - touchesLoc.y) * 1
                let dx = Float(p.x - touchesLoc.x) * 1
                
                // FIXME: need to identify touches
                if dy > 0.1 || dx > 0.1 || dy < -0.1 || dx < -0.1 { touchesLoc = p;return }  //eliminates flickering caused by different first touch selection
                
                
                currentScene.rotation = float3(currentScene.rotation.x - dy, currentScene.rotation.y, currentScene.rotation.z + dx)
                //print(currentScene.rotation)
                
                
            break

            
        default:
            break
        }
    }
    
    
    override func mouseDown(with theEvent: NSEvent) {
        mouseLoc = theEvent.locationInWindow
    }
    
    override func rightMouseDown(with theEvent: NSEvent) {
        currentScene.userSelection()
    }
    
    override func magnify(with event: NSEvent) {
        let m = Float(event.magnification)
        currentScene.magnification += m
    }
    
    //scene translation
    override func mouseDragged(with theEvent: NSEvent) {
        
        let p = theEvent.locationInWindow
        let dy = Float(p.y - mouseLoc.y)
        let dx = Float(p.x - mouseLoc.x)
        
        let cosr = abs(cos(currentScene.rotation.z))
        let sinr = abs(sin(currentScene.rotation.z))
        
        let dify = 1 / currentScene.magnification * (cosr * dy + sinr * dy)
        let difx = 1 / currentScene.magnification * (cosr * dx + sinr * dx)
        
        
        currentScene.position = float3(currentScene.position.x + difx, currentScene.position.y + dify, currentScene.position.z)
        
        mouseLoc = p
        
    }

    
}

