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
vertex VertexOut postVert(const device VertexIn* vertex_array [[ buffer(0) ]],
                                 unsigned int vid [[ vertex_id ]]) {
    
    VertexOut out;
    
    float4 tempPosition = float4((vertex_array[vid].position), 0.0, 1.0);
    out.position = tempPosition;
    // 1 - is a cheap hack to fix a flip in the coords I can't figure out
    out.texCoord = 1 - vertex_array[vid].texcoord;
    
    
    return out;
}

// Fragment shader function

fragment float4 postFrag(VertexOut in [[stage_in]],
                                texture2d<float> composition [[ texture(0) ]]) {
    
    constexpr sampler texSampler(min_filter::linear, mag_filter::linear);

    //pass through
    float2 rcpFrame = float2(1.0 / 640, 1.0 / 480);
    float3 color = composition.sample(texSampler, in.texCoord).rgb;
    //return float4(color, 1.0);
    //
    
    
    // ... or ...
    //based on http://www.geeks3d.com/20110405/fxaa-fast-approximate-anti-aliasing-demo-glsl-opengl-test-radeon-geforce/3/
    
    //---------------------------------------------------------
    #define FXAA_REDUCE_MIN   (1.0/128.0)
    #define FXAA_REDUCE_MUL   (1.0/8.0)
    #define FXAA_SPAN_MAX     8.0
    //---------------------------------------------------------
    float3 rgbNW = composition.sample(texSampler, in.texCoord, int2(-1, 1)).rgb;
    float3 rgbNE = composition.sample(texSampler, in.texCoord, int2(1, 1)).rgb;
    float3 rgbSW = composition.sample(texSampler, in.texCoord, int2(-1, -1)).rgb;
    float3 rgbSE = composition.sample(texSampler, in.texCoord, int2(1, -1)).rgb;
    float3 rgbM  = composition.sample(texSampler, in.texCoord).rgb;
    //---------------------------------------------------------
    float3 luma = float3(0.299, 0.587, 0.114);
    float lumaNW = dot(rgbNW, luma);
    float lumaNE = dot(rgbNE, luma);
    float lumaSW = dot(rgbSW, luma);
    float lumaSE = dot(rgbSE, luma);
    float lumaM  = dot(rgbM,  luma);
    //---------------------------------------------------------
    float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
    float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));
    //---------------------------------------------------------
    float2 dir;
    dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
    dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));
    //---------------------------------------------------------
    float dirReduce = max(
                          (lumaNW + lumaNE + lumaSW + lumaSE) * (0.25 * FXAA_REDUCE_MUL),
                          FXAA_REDUCE_MIN);
    float rcpDirMin = 1.0/(min(abs(dir.x), abs(dir.y)) + dirReduce);
    dir = min(float2( FXAA_SPAN_MAX,  FXAA_SPAN_MAX),
              max(float2(-FXAA_SPAN_MAX, -FXAA_SPAN_MAX),
                  dir * rcpDirMin)) * rcpFrame.xy;
    //--------------------------------------------------------
    float3 rgbA = (1.0/2.0) * (
                             composition.sample(texSampler, in.texCoord + dir * (1.0/3.0 - 0.5)).xyz +
                             composition.sample(texSampler, in.texCoord + dir * (2.0/3.0 - 0.5)).xyz);
    float3 rgbB = rgbA * (1.0/2.0) + (1.0/4.0) * (
                                                composition.sample(texSampler, in.texCoord + dir * (0.0/3.0 - 0.5)).xyz +
                                                composition.sample(texSampler, in.texCoord + dir * (3.0/3.0 - 0.5)).xyz);
    float lumaB = dot(rgbB, luma);
    if((lumaB < lumaMin) || (lumaB > lumaMax)) return float4(rgbA , 1.0);
    
    return float4(rgbB, 1.0);
    
}


