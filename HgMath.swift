//
//  HgMath.swift
//  mercury
//
//  Created by Joshua Knapp on 9/29/15.
//  Copyright © 2015 Joshua Knapp. All rights reserved.
//

import Foundation
import simd

public extension float4x4 {
    //column-major format!
    
    init(scale:float3){
        self.init(
            [   float4(scale.x, 0.0,  0.0, 0.0),
                float4(0.0, scale.y,  0.0, 0.0),
                float4(0.0, 0.0,  scale.z, 0.0),
                float4(0.0, 0.0,  0.0, 1.0)
            ]
        )
        
    }
    
    init(translation:float3){
        self.init(
            [   float4(1.0, 0.0,  0.0, 0.0),
                float4(0.0, 1.0,  0.0, 0.0),
                float4(0.0, 0.0,  1.0, 0.0),
                float4(translation.x, translation.y,  translation.z, 1.0)
            ]
        )
    }
    
    init(XRotation:Float){
        
        let cos = cosf(XRotation)
        let sin = sinf(XRotation)
        self.init(
            [   float4(1.0, 0.0,  0.0, 0.0),
                float4(0.0, cos,  sin, 0.0),
                float4(0.0, -sin, cos, 0.0),
                float4(0.0, 0.0,  0.0, 1.0)
            ]
        )
        
    }
    
    init(YRotation:Float){
        let cos = cosf(YRotation)
        let sin = sinf(YRotation)
        self.init(
            [   float4(cos, 0.0, -sin, 0.0),
                float4(0.0, 1.0,  0.0, 0.0),
                float4(sin, 0.0,  cos, 0.0),
                float4(0.0, 0.0,  0.0, 1.0)
            ]
        )
    }
    
    init(ZRotation:Float){
        let cos = cosf(ZRotation)
        let sin = sinf(ZRotation)
        self.init(
            [
                float4(cos, sin, 0.0, 0.0),
                float4(-sin, cos, 0.0, 0.0),
                float4(0.0, 0.0, 1.0, 0.0),
                float4(0.0, 0.0, 0.0, 1.0)
            ]
        )
    }
    
    /**
     Unlike OpenGL, metal uses a 2x2x1 view space (OpenGL uses a 2x2x2 view space)
     */
    init(orthoWithLeft left:Float, right:Float, bottom:Float, top:Float, nearZ:Float, farZ:Float){
        
        let rsl = right - left
        let tsb = top - bottom
        let fsn = farZ - nearZ
        
        let P = float4(2.0 / rsl,0,0,0)
        let Q = float4(0, 2.0 / tsb, 0,0)
        let R = float4(0,0, -1.0 / fsn,0)
        let S = float4(0, 0, -nearZ / fsn, 1.0)
    
        self.init([P, Q, R, S]);
    }
    
    
    /**
    Like gluLookAt
    
    - parameter eye_: The coordinate of the camera
    - parameter center_: The coordinate of the point being looked at
    - parameter up_: The coordinate of the camera's up vector
    
    - returns: a float4x4 matrix that transforms world coordinates to eye coordinates
    */
    init(lookAtFromEyeX eyeX:Float, eyeY:Float, eyeZ:Float, centerX:Float, centerY:Float, centerZ:Float, upX:Float, upY:Float, upZ:Float){
        
        
        let ev = float3(eyeX, eyeY, eyeZ)
        let cv = float3(centerX, centerY, centerZ)
        let uv = float3(upX, upY, upZ)
        
        let zAxis = normalize(cv - ev);
        let xAxis = normalize(cross(uv, zAxis));
        let yAxis = cross(zAxis, xAxis);
        
        let P = float4(xAxis.x, yAxis.x, zAxis.x, 0)
        let Q = float4(xAxis.y, yAxis.y, zAxis.y, 0)
        let R = float4(xAxis.z, yAxis.z, zAxis.z, 0)
        let S = float4(dot(xAxis, ev), dot(yAxis, ev), dot(zAxis, ev), 1)
        
        self.init([P, Q, R, S]);
    }
    
    /**
    Like gluMakePerspective
    
    - parameter fovy: The field of view range in degrees
    - parameter aspect: The width to height ratio of the viewport
    - parameter near: The near clipping plane
    - parameter far: The far clipping plane
    - returns: A float4x4 matrix that applies a perspective transformation
    */
    init(perspectiveWithFOVY fovy:Float, aspect:Float, near:Float, far:Float) {
        let angle = radians(0.5 * fovy)
        let yScale = 1 / tan(angle)
        let xScale = yScale / aspect
        let zScale = far / (far - near)
        let wScale = -(far * near) / (far - near)
        
        let P = float4(xScale, 0, 0, 0)
        let Q = float4(0, yScale, 0, 0)
        let R = float4(0, 0, zScale, 1)
        let S = float4(0, 0, wScale, 0)
        
        self.init([P, Q, R, S])
    }
     
}

extension float3x3 {
    init(mat4:float4x4) {
        let x = float3(mat4[0].x, mat4[0].y, mat4[0].z)
        let y = float3(mat4[1].x, mat4[1].y, mat4[1].z)
        let z = float3(mat4[2].x, mat4[2].y, mat4[2].z)
        self.init([x,y,z])
    }
}

public func ==(lhs:float2, rhs:float2) -> Bool {
    return lhs.x == rhs.x && lhs.y == rhs.y
}

///Takes degrees, returns radians
public func radians(_ degrees: Float) -> Float { return degrees * .pi / 180.0 }

///Returns a random integer between and including the input values
public func random(_ low: Int, high: Int) -> Int {
    return Int(arc4random_uniform(UInt32(high - low) + 1) + UInt32(low))
}

