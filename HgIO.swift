//
//  HgIO.swift
//  IOSMercury
//
//  Created by Joshua Knapp on 8/2/17.
//

import Foundation
import SceneKit.ModelIO

class HgOBJNode: HgNode {
    
    init?(name: String) {
        super.init()
        var OBJStringContent:String
        do {
            let urlpath = Bundle.main.path(forResource: name, ofType: "obj")
            let url = NSURL.fileURL(withPath: urlpath!)
            OBJStringContent = try String(contentsOf: url)
        } catch {
            print("Could not load OBJ file \(error)")
            return
        }
        
        let lines = OBJStringContent.components(separatedBy: CharacterSet.newlines)
    
        var positions : [(Float, Float, Float)] = [] //x,y,z
        var normals : [(Float, Float, Float)] = [] // x,y,z
        var uvs : [(Float, Float)] = []// u,v
        var faces : [(p:Int, uv:Int, n:Int)] = [] // xyz,uv,n index
        
        //iterate through lines in file and fill position, normal, and uv array of values.  fill faces with indexes of above values.
        for line in lines {
            if (line.hasPrefix("v ")){//Vertex
                let components = line.components(separatedBy: CharacterSet.whitespaces)
                positions.append((Float(components[1])!,Float(components[2])!, Float(components[3])! ) )
            } else if (line.hasPrefix("vt ")) {//UV coords
                let components = line.components(separatedBy: CharacterSet.whitespaces)
                uvs.append((Float(components[1])!,1.0 - Float(components[2])! ))  //obj 0,0 is top left, mtl is bottom left
            } else if (line.hasPrefix("vn ")) {//Normal coords
                let components = line.components(separatedBy: CharacterSet.whitespaces)
                normals.append((Float(components[1])!,Float(components[2])!, Float(components[3])! ) )
            } else if (line.hasPrefix("f ")) {//Face with vertices/uv/normals... stunningly OBJ uses 1 based lists
                let components = line.components(separatedBy: CharacterSet.whitespaces).dropFirst()
                
                //this is troubling because faces may be defined in fans or triangles...
                //Only do triangles for now
                //var indices = [(p:Int, uv:Int, n:Int)]()
                for component in components {
                    let bits = component.components(separatedBy: "/")
                    let p = Int(bits[0]), uv = Int(bits[1]), n = Int(bits[2])
                    faces.append((p! - 1, uv! - 1, n! - 1 ))
                    // FIXME: get rid of !
                    //indices.append((p! - 1, uv! - 1, n! - 1 ))  // -1 to turn that OBJ 1 based array into 0 based sensibility
                }
                /*
                // manually generate a triangle-fan
                var idx = 1
                for _ in 1..<indices.count - 1 {
                    faces.append(indices[0])
                    faces.append(indices[idx])
                    faces.append(indices[idx + 1])
                    
                    idx = idx + 1
                }*/
            }
        }
        
        if positions.isEmpty || faces.isEmpty || faces.isEmpty {
            print("Missing data")
            return nil
        }
        
        vertexCount = faces.count
        vertexData = Array(repeating: vertex(), count: vertexCount)
        
        for (idx,face) in faces.enumerated() {
            if face.p < positions.count {
                vertexData[idx].position = positions[face.p]
            } else {
                print("Tried to access index \(face.p) of positions with count \(positions.count)")
            }
            
            vertexData[idx].texture = uvs[face.uv]
            if face.n < normals.count {
                vertexData[idx].normal = normals[face.n]
            } else {
                print("Tried to access index \(face.n) of normals with count \(normals.count)")
            }
        }
        
        print("OBJ: loaded")
    }
}



