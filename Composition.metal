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
    float3 lightPosition;
};

struct Uniforms{
    float4x4 modelMatrix;
    float4x4 projectionMatrix;
    float4x4 lightMatrix; //takes modelMatrix into light position for zBuffer writing
    float3x3 normalMatrix;
    float3 lightPosition;
};


// Vertex shader function
vertex VertexOut compositionVert(const device VertexIn* vertex_array [[ buffer(0) ]],
                                 const device Uniforms& uniforms [[ buffer(1) ]],
                           unsigned int vid [[ vertex_id ]]) {
    
    VertexOut out;
    
    float4 tempPosition = float4((vertex_array[vid].position), 0.0, 1.0);
    out.position = tempPosition;
    out.texCoord = vertex_array[vid].texcoord;
    out.lightPosition = uniforms.lightPosition;
    
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
    float sun_diffuse = fmax(dot(n_s * 2.0 - 1.0, normalize(float3(0,0,-1))), 0.2);
    diffuse += float3(0.75) * sun_diffuse;
    diffuse *= albedo.sample(texSampler, in.texCoord).rgb;
    diffuse += diffuse;
    return float4(diffuse, 1.0);
   
}

//based on http://www.geeks3d.com/20110405/fxaa-fast-approximate-anti-aliasing-demo-glsl-opengl-test-radeon-geforce/3/
