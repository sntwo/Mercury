/*
 <samplecode>
 <abstract>
 GBuffer shader
 </abstract>
 </samplecode>
 */

#include <metal_graphics>
#include <metal_texture>
#include <metal_matrix>
#include <metal_math>

#include "common.h"

using namespace AAPL;
using namespace metal;

struct VertexIn
{
    packed_float3 position;
    packed_float3 normal;
    packed_float2 texcoord;
    packed_float4 ambientColor;
    packed_float4 diffuseColor;
};

struct Uniforms{
    float4x4 modelMatrix;
    float4x4 projectionMatrix;
    float4x4 lightMatrix; //takes modelMatrix into light position for zBuffer writing
    float3x3 normalMatrix;
    float3 lightPosition;
};


struct VertexOut{
    float4 position [[position]];
    float4 color;
    float4 normal;
    float4 v_model;
};

struct GBufferOut {
    float4 albedo [[color(0)]];
    float4 normals [[color(1)]];
    float4 positions [[color(2)]];
};


vertex VertexOut gBufferVert(const device VertexIn* vertex_array [[ buffer(0) ]],
                             const device Uniforms& uniforms [[ buffer(1) ]],
                             unsigned int vid [[ vertex_id ]]) {
    VertexOut out;
    VertexIn vin = vertex_array[vid];
    
    float4 in_position = float4(vin.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelMatrix * in_position;
    float3 normal = vin.normal;
    float3 eye_normal = normalize(uniforms.normalMatrix * normal);
   
    float n_dot_l = dot(eye_normal.rgb, normalize(uniforms.lightPosition));
    n_dot_l = fmax(0.0, n_dot_l);
    
    out.color = float4(vin.ambientColor + vin.diffuseColor * n_dot_l);
    out.normal = float4(eye_normal, 0.0);
    out.v_model = uniforms.modelMatrix * in_position;
    return out;
}

fragment GBufferOut gBufferFrag(VertexOut in [[stage_in]])
{
    float3 world_normal = in.normal.xyz;
    float scale = rsqrt(dot(world_normal, world_normal)) * 0.5;
    world_normal = world_normal * scale + 0.5;
    
    GBufferOut out;
    out.albedo = in.color;
    out.normals.xyz = world_normal;
    out.positions = in.v_model;
    return out;
}