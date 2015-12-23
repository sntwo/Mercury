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
    
    private var bufferIndex = 0

    var currentScene: HgScene!
    
    var mouseLoc:NSPoint = NSPoint(x: 0,y: 0)
    var touchesLoc:NSPoint = NSPoint(x:0, y:0)
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // setup view properties
        let view = self.view as! MTKView
        view.delegate = self
        view.device = HgRenderer.device
        view.sampleCount = 1
        view.colorPixelFormat = MTLPixelFormat.BGRA8Unorm
        
        self.view.acceptsTouchEvents = true
        
        HgRenderer.sharedInstance.view = view
        currentScene = MainScene(view: view)
        currentScene.run()
        //currentScene.controller = self
    
    }

    //MARK: MTKViewDelegate Methods
    func drawInMTKView(view: MTKView) {
       
        if let cur = currentScene {
            cur.render()
        }
    }
    
    
    func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    override func magnifyWithEvent(event: NSEvent) {
        let m = event.magnification
        currentScene.magnification += Float(m)
        //print("Set magnification to \(m)")
    }
    
    
    override func touchesMovedWithEvent(event: NSEvent) {
    
        let touches = event.touchesMatchingPhase(.Moved, inView: view)
        
        guard let touch = touches.first else { return }
        
        
        switch touches.count {
        case 1:
            break
            
        case 2:  //rotate scene
            let p = touch.normalizedPosition
            defer { touchesLoc = p }
            let dy = Float(p.y - touchesLoc.y) * 10
            let dx = Float(p.x - touchesLoc.x) * 10
            currentScene.rotation = float3(currentScene.rotation.x - dy, currentScene.rotation.y, currentScene.rotation.z + dx)
            print("x rot is \(currentScene.rotation.x)")
            break
            
        default:
            break
        }
    }
    
    override func touchesBeganWithEvent(event: NSEvent) {
        //print("handling touches")

        let touches = event.touchesMatchingPhase(.Touching, inView: view)
        if touches.count == 2 {
            if let touch = touches.first {
                touchesLoc = touch.normalizedPosition
           }
        }

    }
    
    override func mouseDown(theEvent: NSEvent) {
        mouseLoc = theEvent.locationInWindow
    }
    
    override func rightMouseDown(theEvent: NSEvent) {
        currentScene.userSelection()
    }
    
    
    //scene translation
    override func mouseDragged(theEvent: NSEvent) {
        /*
        let p = theEvent.locationInWindow
        let dy = Float(p.y - mouseLoc.y)
        let dx = Float(p.x - mouseLoc.x)
        let cosr = (cos(currentScene.rotation.z))
        let sinr = (sin(currentScene.rotation.z))
        //let cosx = (cos(currentScene.rotation.x))
        //let sinx = (sin(currentScene.rotation.x))
        //print("cosr    sinr    cosx    sinx")
        //print(cosr, sinr, cosx, sinx)
       
        let dify = 1 / currentScene.magnification * (cosr * dy - sinr * dx)
        let difx = 1 / currentScene.magnification * (cosr * dx + sinr * dy)
  
        currentScene.position = float3(currentScene.position.x + difx, currentScene.position.y + dify, currentScene.position.z)
        
        mouseLoc = p
        */
    }

    
}

