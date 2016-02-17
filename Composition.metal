/*
 <samplecode>
 <abstract>
 Composition shader
 </abstract>
 </samplecode>
 */

#include <metal_graphics>
#include <metal_geometric>
#include <metal_stdlib>


using namespace metal;

struct VertexIn
{
    packed_float2 position;
    packed_float2 texcoord;
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord [[user(texturecoord)]];
};

// Vertex shader function
vertex VertexOut compositionVert(const device VertexIn* vertex_array [[ buffer(0) ]],
                           unsigned int vid [[ vertex_id ]]) {
    VertexOut out;
    
    float4 tempPosition = float4((vertex_array[vid].position), 0.0, 1.0);
    out.position = tempPosition;
    out.texCoord = vertex_array[vid].texcoord;
    
    return out;
}

// Fragment shader function
 
fragment float4 compositionFrag(VertexOut in [[stage_in]],
                            texture2d<float> albedo [[ texture(0) ]],
                            texture2d<float> lightData [[ texture(1) ]],
                            texture2d<float> normals [[ texture(2) ]]) {
    
    constexpr sampler texSampler(min_filter::linear, mag_filter::linear);
    
    float4 light = lightData.sample(texSampler, in.texCoord);
    
    float3 diffuse = light.rgb;
    float3 n_s = normals.sample(texSampler, in.texCoord).rgb;
    
    float sun_diffuse = fmax(dot(n_s * 2.0 - 1.0, float3(0.0, 0.0, 1.0)), 0.1);
    
    diffuse += float3(0.75) * sun_diffuse;
    diffuse *= albedo.sample(texSampler, in.texCoord).rgb;
    
    diffuse += diffuse;
    
    //return float4(albedo.sample(texSampler, in.texCoord).rgb, 1.0);
    //return float4(light.a);
    return float4(diffuse, 1.0);
    //return float4(1,1,0,1);
}