#include <metal_stdlib>

using namespace metal;

struct Uniforms{
    float4x4 modelMatrix;
    float4x4 projectionMatrix;
    float4x4 lightMatrix; //takes modelMatrix into light position for zBuffer writing
    float3x3 normalMatrix;
    float3 lightPosition;
};

struct LightVertexIn{
    float4 position;
};

struct VertexIn
{
    packed_float3 position;
    packed_float3 normal;
    packed_float2 texcoord;
    packed_float4 ambientColor;
    packed_float4 diffuseColor;
};

struct LightVertexOutput{
    float4 position [[position]];
    float3 v_view;
    float2 distance;
};

struct LightFragmentInput{
    float4   view_light_position;
    float4   light_color_radius;
    float4   light_direction_coherance;
    float2   screen_size;
};


vertex LightVertexOutput lightVert(device VertexIn* vertex_array [[ buffer(0) ]],
                              constant Uniforms& uniforms [[ buffer(1) ]],
                              uint vid [[ vertex_id] ])

{
    LightVertexOutput output;
    
    float4 tempPosition = float4(vertex_array[vid].position, 1.0);
    output.position = uniforms.projectionMatrix * uniforms.modelMatrix * tempPosition;
    output.distance = vertex_array[vid].texcoord;
   
    return output;
}


fragment float4 lightFrag(LightVertexOutput in [[stage_in]],
                          constant LightFragmentInput *lightData [[buffer(0)]],
                          texture2d<float> normalsAndDepth [[ texture(0) ]],
                          texture2d<float> structurePosition [[ texture(1) ]])
{
    float2 txCoords = in.position.xy/lightData->screen_size;  
    constexpr sampler texSampler;
    float4 gBuffers = normalsAndDepth.sample(texSampler, txCoords);
    float4 pos = structurePosition.sample(texSampler, txCoords);
    float3 normal = gBuffers.rgb * 2.0 - 1.0;
    float3 lightPosition = lightData->view_light_position.xyz;
    float3 lightVector = lightPosition - pos.xyz;
    float lightRadius = lightData->light_color_radius.w;

    float distance = length(lightVector);
    float diffuseIntensity = 1.0 - distance * 1.5 / lightRadius;
    
    float diffuseResponse = fmax(dot(normal, normalize(lightVector)), 0.0);
    
    float4 light  = float4(0.0,0.0,0.0, 1.0);
    light.rgb = lightData->light_color_radius.xyz * diffuseIntensity * diffuseResponse;
    
    return light;
}
