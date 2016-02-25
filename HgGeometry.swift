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
            p = q++
        }
        return A * 0.5
    }
    
    private func snip(contour:[float2], u:Int, v:Int, w:Int, n:Int, inout V:[Int]) -> Bool {
        
        var Ax:Float, Ay:Float, Bx:Float, By:Float, Cx:Float, Cy:Float, Px:Float, Py:Float
        
        Ax = contour[V[u]].x
        Ay = contour[V[u]].y
        
        Bx = contour[V[v]].x
        By = contour[V[v]].y
        
        Cx = contour[V[w]].x
        Cy = contour[V[w]].y
        
        if EPSILON > (((Bx-Ax)*(Cy-Ay)) - ((By-Ay)*(Cx-Ax))) { return false}
        
        for var p = 0; p < n; p++ {
            if (p == u) || (p == v) || (p == w) { continue }
            Px = contour[V[p]].x
            Py = contour[V[p]].y
            if insideTriangle(Ax,Ay: Ay,Bx: Bx,By: By,Cx: Cx,Cy: Cy,Px: Px,Py: Py) { return false }
        }
        
        return true
    }
    
    ///decides if a point p is inside of the triangle defined by A,B,C
    private func insideTriangle(Ax:Float, Ay:Float, Bx:Float, By:Float, Cx:Float, Cy:Float, Px:Float, Py:Float) -> Bool {
        
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
        var V = [Int](count: points.count, repeatedValue:0)
        
        //make sure it is counter-clockwise
        if 0 < getArea() {
            for var v=0; v < points.count; v++ { V[v] = v}
        } else {
            for var v=0; v < points.count; v++ { V[v] = (points.count-1)-v }
        }
        
        var nv = points.count
        var count = 2 * nv
        
        for var v = nv - 1; nv > 2; {
            
            count--
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
                for var t = v + 1; t < nv; t++ {
                    V[s] = V[t]
                    s++
                }
                nv--
            
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
    
    func eval(t:Float) -> Float{
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
        inverseAngle = (angle + Float(M_PI / 2 ))
    }
    
    func broadenOffset(width:Float) -> float2 {
        return float2(cos(inverseAngle) * width / 2, sin(inverseAngle) * width / 2)
    }
    
    //takes of length from both ends
    func chop(length:Float){
        
        guard straightLength > length * 2 else {print("tried to chop more off HgLine than there is!");return}
        
        let offset = float2(cos(angle) * length, sin(angle) * length)
        p0 += offset
        p1 -= offset
    }
    
    func tesselate(width:Float) -> [float2] {
        
        let offset = broadenOffset(width)
        
        let a = p0 + offset
        let b = p0 - offset
        let c = p1 + offset
        let d = p1 - offset
        
        var ret = [float2]()
        ret += [b, a, c, c , d, b]
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
    
    func tesselate(divisions:Int) -> [float2] {
        let angleIncrement = Float(2 * M_PI) / Float(divisions)
        var angle:Float = 0
        var ret = [float2]()
        for var i = 0; i < divisions; i++ {
            ret += [center,
                    float2(cos(angle) * radius, sin(angle) * radius),
                    float2(cos(angle + angleIncrement) * radius, sin(angle + angleIncrement) * radius)]
            angle += angleIncrement
        }
        return ret
    }
}

///A line with 2 control points that define curvature using centripetal catmull rom quadratic, parametric equations...?
class HgSpline {
    
    ///start point of the line
    var p0:float2
    ///control point 1
    var p1:float2
    //control point 2
    var p2:float2
    ///end point of the line
    var p3:float2
    
    private var cpX:CubicPoly?
    private var cpY:CubicPoly?
    
    var midPoint:float2 { get { return float2((p0.x + p3.x) / 2, (p0.y + p3.y) / 2) } }
    
    let vector:float2
    let straightLength:Float
    let angle:Float
    
    init(p0:float2, p3:float2) {
        self.p0 = p0
        self.p3 = p3
        vector = p3 - p0
        straightLength = length(vector)
        angle = atan2f(self.vector.y, self.vector.x)
        let quarterOffset = float2(cos(angle) * straightLength / 3, sin(angle) * straightLength / 3)
        p1 = p0 + quarterOffset
        p2 = p1 + quarterOffset
    }
    
    func createCentripetalCatmullRoms(p0:float2, p1:float2, p2:float2, p3:float2) {
        
        var dt0 = powf(distance_squared(p0, p1), 0.25)
        var dt1 = powf(distance_squared(p1, p2), 0.25)
        var dt2 = powf(distance_squared(p2, p3), 0.25)
        
        // safety check for repeated points
        if dt1 < 0.0001   { dt1 = 1.0 }
        if dt0 < 0.0001   { dt0 = dt1 }
        if dt2 < 0.0001   { dt2 = dt1 }
        
        cpX = CubicPoly(x0: p0.x, x1: p1.x, x2: p2.x, x3: p3.x, dt0: dt0, dt1: dt1, dt2: dt2)
        cpY = CubicPoly(x0: p0.y, x1: p1.y, x2: p2.y, x3: p3.y, dt0: dt0, dt1: dt1, dt2: dt2)
    }
    
    func listPoints(step:Float) -> [float2]{
        createCentripetalCatmullRoms(p0, p1: p1, p2: p2, p3: p3)
        guard let x = cpX, y = cpY else {fatalError("no centripetal function")}
        var ret = [float2]()
        var i:Float
        for i = step; i < 1; i += step {
            ret.append(float2(x.eval(i), y.eval(i)))
        }
        return ret
    }
    
    func tesselate(step:Float, width:Float) -> [float2] {
        
        //make parrallel splines
        let lineA = HgLine(p0: p0, p1: p1)
        let lineB = HgLine(p0: p2, p1: p3)
        let offsetA = lineA.broadenOffset(width)
        let offsetB = lineB.broadenOffset(width)
        
        var splineA = HgSpline(p0: p0 + offsetA, p3: p3 + offsetB)
        splineA.p1 = p1 + offsetA
        splineA.p2 = p2 + offsetB
        
        var splineB = HgSpline(p0: p0 - offsetA, p3: p3 - offsetB)
        splineB.p1 = p1 - offsetA
        splineB.p2 = p2 - offsetB
        
        //put in clockwise order
        var t = (splineB.p0.x - splineA.p0.x) * (splineB.p0.y + splineA.p0.y)
        t += (splineA.p3.x - splineB.p0.x) * (splineA.p3.y + splineB.p0.y)
        t += (splineA.p0.x - splineA.p3.x) * (splineA.p0.y + splineA.p3.y)
        
        if t < 0 {
            (splineA, splineB) = (splineB, splineA)
        }
        
        let listA = splineA.listPoints(step)
        let listB = splineB.listPoints(step)
        
        var ret = [float2]()

        ret += [splineA.p0, splineB.p0, splineA.p1, splineA.p1, splineB.p0, splineB.p1] // segment p0-p1
        ret += [splineA.p1, splineB.p1, listA[0], listA[0], splineB.p1, listB[0]]
        
        var i:Int
        for i = 0; i < listA.count - 1; i++ {
            ret += [listA[i], listB[i], listA[i+1], listA[i + 1], listB[i], listB[i + 1]] //segment p1-p2 curves
        }
        ret += [splineA.p3, splineB.p3, listA[i], listA[i], splineB.p3, listB[i]]
        ret += [splineA.p2, splineB.p2, splineA.p3, splineA.p3, splineB.p2, splineB.p3]  //segment p2-p3
        
        
        return ret
    }
}
