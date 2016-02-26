//
//  HgIOSViewController.swift
//  mercury
//
//  Created by Joshua Knapp on 10/15/15.
//  Copyright © 2015 Joshua Knapp. All rights reserved.
//

import Foundation


import Foundation
import MetalKit

let MaxBuffers = 3

class HgIOSViewController: UIViewController, MTKViewDelegate, HgViewController {
    
    let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    let inflightSemaphore = dispatch_semaphore_create(MaxBuffers)
    var bufferIndex = 0
    
    var currentScene: HgScene!
    var mouseLoc:CGPoint = CGPoint(x: 0,y: 0)
    var touchesLoc:CGPoint = CGPoint(x:0, y:0)
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // setup view properties
        let view = self.view as! MTKView
        view.delegate = self
        
        view.device = HgRenderer.device
        view.sampleCount = 1
        view.colorPixelFormat = MTLPixelFormat.BGRA8Unorm
        //view.acceptsTouchEvents = true
        
        HgRenderer.sharedInstance.view = view
        currentScene = MainScene(view: view)
        currentScene.run()
        //currentScene.controller = self
        
            //gesture recognizers
        let magrec = UIPinchGestureRecognizer(target: self, action: Selector("magnify:"))
        view.addGestureRecognizer(magrec)
        
        let pan1rec = UIPanGestureRecognizer(target: self, action: Selector("pan2:"))
        pan1rec.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan1rec)
        
        let pan2rec = UIPanGestureRecognizer(target: self, action: Selector("pan:"))
        pan2rec.maximumNumberOfTouches = 2
        pan2rec.minimumNumberOfTouches = 2
        view.addGestureRecognizer(pan2rec)
        
    }
    
    //MARK: MTKViewDelegate Methods
    func drawInMTKView(view: MTKView) {
        if let cur = currentScene {
            cur.render()
        }
    }
    
    
    func mtkView(view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
    
    
    func magnify(recognizer:UIPinchGestureRecognizer) {
        let m = Float(recognizer.scale)
        recognizer.scale = 1
        currentScene.magnification *= m
    }
    
    func pan(recognizer:UIPanGestureRecognizer) {
        //print("pan1")
        let p = recognizer.translationInView(self.view)
    
        //if currentScene.rotation.x  - dpy > -1 && currentScene.rotation.x - dpy < 1
        //{
        currentScene.rotation = float3(currentScene.rotation.x + Float(p.y) / 100, currentScene.rotation.y, currentScene.rotation.z + Float(p.x) / 100)
        //}
        recognizer.setTranslation(CGPoint(x: 0,y: 0), inView: self.view)
        //print("current x rotation is \(currentScene.rotation.x)")
        

    }
    
    func pan2(recognizer:UIPanGestureRecognizer) {
        // print("pan2")
        let p = recognizer.translationInView(self.view)
        let dy = Float(p.y - touchesLoc.y)
        let dx = Float(p.x - touchesLoc.x)
        
        let cosr = cos( currentScene.rotation.z)
        let sinr = sin( currentScene.rotation.z)
        
        //print("Cosr is \(cosr)")
        //print("sinr is \(sinr)")
        
        let dify = -1 * cosr * dy - 1 * sinr * dx
        let difx = 1 * cosr * dx - 1 * sinr * dy
        
        
        
        //print("dx = \(dx)")
        //print("dy = \(dy)")
        currentScene.position = float3(currentScene.position.x - difx, currentScene.position.y - dify, currentScene.position.z)
        
        //touchesLoc = p
        recognizer.setTranslation(CGPoint(x: 0,y: 0), inView: self.view)
    }
         
}
