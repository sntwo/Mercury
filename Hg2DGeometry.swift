//
//  HgGeometry.swift
//  mercury
//
//  Created by Joshua Knapp on 10/26/15.
//  Copyright © 2015 Joshua Knapp. All rights reserved.
//

import Foundation
import simd

struct HgPolygon {
    
    ///a set of points that describe the boundary of the polygon in counterclockwise order
    var points: [float2]

    let EPSILON:Float = 0.0000000001

    //calculates the area, negative values indicate counterclockwise order
    func getArea() -> Float {
        let n = points.count
        var A:Float = 0
        var p = n - 1
        for var q in 0..<n {
            A += points[p].x * points[q].y - points[q].x * points[p].y
            p = q
            q += 1
        }
        return A * 0.5
    }
    
    fileprivate func snip(_ contour:[float2], u:Int, v:Int, w:Int, n:Int, V:inout [Int]) -> Bool {
        
        var Ax:Float, Ay:Float, Bx:Float, By:Float, Cx:Float, Cy:Float, Px:Float, Py:Float
        
        Ax = contour[V[u]].x
        Ay = contour[V[u]].y
        
        Bx = contour[V[v]].x
        By = contour[V[v]].y
        
        Cx = contour[V[w]].x
        Cy = contour[V[w]].y
        
        if EPSILON > (((Bx-Ax)*(Cy-Ay)) - ((By-Ay)*(Cx-Ax))) { return false}
        
        
        var p = 0
        while p < n {
            if (p == u) || (p == v) || (p == w) { continue }
            Px = contour[V[p]].x
            Py = contour[V[p]].y
            if insideTriangle(Ax,Ay: Ay,Bx: Bx,By: By,Cx: Cx,Cy: Cy,Px: Px,Py: Py) { return false }
            p += 1
        }
        
        return true
    }
    
    ///decides if a point p is inside of the triangle defined by A,B,C
    fileprivate func insideTriangle(_ Ax:Float, Ay:Float, Bx:Float, By:Float, Cx:Float, Cy:Float, Px:Float, Py:Float) -> Bool {
        
        let ax =  Cx - Bx; let ay = Cy - By
        let bx =  Ax - Cx; let by = Ay - Cy
        let cx =  Bx - Ax; let cy = By - Ay
        let apx = Px - Ax; let apy = Py - Ay
        let bpx = Px - Bx; let bpy = Py - By
        let cpx = Px - Cx; let cpy = Py - Cy
        
        let aCROSSbp = ax * bpy - ay * bpx
        let cCROSSap = cx * apy - cy * apx
        let bCROSScp = bx * cpy - by * cpx
        
        return aCROSSbp >= 0 && bCROSScp >= 0 && cCROSSap >= 0

    }
    
    func tesselate() -> [float2] {
        
        var result = [float2]()
    
        
        //make a list of vertices
        var V = [Int](repeating: 0, count: points.count)
        
        //make sure it is counter-clockwise
        if 0 < getArea() {
            for v in 0..<points.count {
                V[v] = v
            }
        } else {
            for v in 0..<points.count {
                V[v] = (points.count-1)-v
            }
        }
        
        var nv = points.count
        var count = 2 * nv
        
        var v = nv - 1
        while nv < 3 {
            
            count -= 1
            if 0 >= count {print("error in triangulate loop, count is \(count)"); exit(0)}
            
            var u = v
            if nv <= u { u = 0 }
            v = u + 1
            if nv <= v { v = 0 }
            var w = v + 1
            if nv <= w { w = 0 }
            
            if snip(points, u: u, v: v, w: w, n: nv, V: &V) {
                let a = V[u]
                let b = V[v]
                let c = V[w]
                
                result += [points[a]]
                result += [points[b]]
                result += [points[c]]
                
                var s = v
                /* remove v from remaining polygon */
        
                for t in v+1..<nv {
                    V[s] = V[t]
                    s += 1
                }
                nv -= 1
            
                count = 2*nv
            }
        
            
        }
        return result
    }
    
}

private struct CubicPoly {
    
    let c0:Float
    let c1:Float
    let c2:Float
    let c3:Float
    
    /*
    * Compute coefficients for a cubic polynomial
    *   p(s) = c0 + c1*s + c2*s^2 + c3*s^3
    * such that
    *   p(0) = x0, p(1) = x1
    *  and
    *   p'(0) = t0, p'(1) = t1.
    */
    
    init(x0:Float, x1:Float, t0:Float, t1:Float) {
        c0 = x0
        c1 = t0
        c2 = -3*x0 + 3*x1 - 2*t0 - t1
        c3 = 2*x0 - 2*x1 + t0 + t1
    }
    
    init(x0:Float, x1:Float, x2:Float, x3:Float, dt0:Float, dt1:Float, dt2:Float){
        // compute tangents when parameterized in [t1,t2]
        var t1 = (x1 - x0) / dt0 - (x2 - x0) / (dt0 + dt1) + (x2 - x1) / dt1
        var t2 = (x2 - x1) / dt1 - (x3 - x1) / (dt1 + dt2) + (x3 - x2) / dt2
        
        // rescale tangents for parametrization in [0,1]
        t1 *= dt1
        t2 *= dt1
        
        self.init(x0:x1, x1:x2, t0:t1, t1:t2)
    }
    
    func eval(_ t:Float) -> Float{
        let t2 = t*t
        let t3 = t2 * t
        return c0 + c1*t + c2*t2 + c3*t3
    }
}

class HgLine {
    
    ///start point of the line
    var p0:float2
    ///end point of the line
    var p1:float2
    
    let vector:float2
    let straightLength:Float
    let angle:Float
    let inverseAngle:Float
    
    init(p0:float2, p1:float2){
        
        self.p0 = p0
        self.p1 = p1
        
        vector = (p1 - p0)
        straightLength = length(vector)
        angle = atan2f(self.vector.y, self.vector.x)
        inverseAngle = angle + .pi / 2
    }
    
    func broadenOffset(_ width:Float) -> float2 {
        return float2(cos(inverseAngle) * width / 2, sin(inverseAngle) * width / 2)
    }
    
    //takes off length from both ends
    func chop(_ length:Float){
        
        guard straightLength > length * 2 else {print("tried to chop more off HgLine than there is!");return}
        
        let offset = float2(cos(angle) * length, sin(angle) * length)
        p0 += offset
        p1 -= offset
    }
    
    func tesselate(_ width:Float) -> [float2] {
        
        let offset = broadenOffset(width)
        
        let a = p0 + offset
        let b = p0 - offset
        let c = p1 + offset
        let d = p1 - offset
        
        var ret = [float2]()
        ret += [a, b, c, c , d, a]
        return ret
    }
    
}

class HgCircle {
    
    var center:float2
    var radius:Float
    
    init(center:float2, radius:Float) {
        self.center = center
        self.radius = radius
    }
    
    func tesselate(_ divisions:Int) -> [float2] {
        let angleIncrement = 2 * .pi / Float(divisions)
        var angle:Float = 0
        var ret = [float2]()
        for _ in 0 ..< divisions {
            ret += [center,
                    float2(cos(angle) * radius, sin(angle) * radius),
                    float2(cos(angle + angleIncrement) * radius, sin(angle + angleIncrement) * radius)]
            angle += angleIncrement
        }
        return ret
    }
}

