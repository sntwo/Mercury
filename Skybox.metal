/*
 <samplecode>
 <abstract>
 Skybox shader
 </abstract>
 </samplecode>
 */

#include <metal_graphics>
#include <metal_geometric>
#include <metal_matrix>
#include <metal_texture>

#include "common.h"

using namespace AAPL;
using namespace metal;

struct VertexOut{
    float4 position [[position]];
    float4 color;
    float4 normal;
    float4 v_model;
    float3 texcoord;
};

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

struct GBufferOut {
    float4 albedo [[color(0)]];
    float4 normals [[color(1)]];
    float4 positions [[color(2)]];
};


vertex VertexOut skyboxVert(constant VertexIn *vertexArray [[buffer(0)]],
                               constant Uniforms &uniforms [[buffer(1)]],
                               uint vid [[vertex_id]] )
{
	VertexOut out;
    VertexIn vin = vertexArray[vid];
    
    float4 in_position = float4(vin.position, 1.0);
    in_position = 1.45 * uniforms.modelMatrix * in_position;
    //set the z value to 1.0 to make it always be the back object
    //see http://ogldev.atspace.co.uk/www/tutorial25/tutorial25.html
    out.position = float4(in_position.x, in_position.y, 1.0,1.0);
    
    //out.normal = float4(eye_normal, 0.0);
    out.normal = float4(0,0,1,0);
    out.texcoord = vin.position;
    return out;

}

fragment GBufferOut skyboxFrag(VertexOut in [[stage_in]],
                                              texturecube<float> skybox_texture [[texture(0)]])
                               
{
    constexpr sampler linear_sampler(min_filter::linear, mag_filter::linear);
	float4 color = skybox_texture.sample(linear_sampler, in.texcoord);
	
    GBufferOut output;

	output.albedo = color;
    output.normals = float4(0,0,1, 1.0);
    output.positions = float4(-10000000,-10000000,-10000000,0);

	return output;
}    
