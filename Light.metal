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
};

struct LightFragmentInput{
    float4   view_light_position;
    float4   light_color_radius;
    float2   screen_size;
};


// This shader is used to render light primitives as geometry.  The runtime side manages
// the stencil buffer such that each light primitive shades single-sided (only the front face or back face contributes light).
// The fragment shader sources all of its input values from the current framebuffer attachments (G-buffer).
vertex LightVertexOutput lightVert(device VertexIn* vertex_array [[ buffer(0) ]],
                              constant Uniforms& uniforms [[ buffer(1) ]],
                              uint vid [[ vertex_id] ])

{
    LightVertexOutput output;
    
    float4 tempPosition = float4(vertex_array[vid].position, 1.0);
    output.position = uniforms.projectionMatrix * uniforms.modelMatrix * tempPosition;
    output.v_view = (uniforms.modelMatrix * tempPosition).xyz;
    
   
    return output;
}


fragment float4 lightFrag(LightVertexOutput in [[stage_in]],
                          constant LightFragmentInput *lightData [[buffer(0)]],
                          texture2d<float> normalsAndDepth [[ texture(0) ]],
                          texture2d<float> lightColor [[ texture(1) ]])
{
    float2 txCoords = in.position.xy/lightData->screen_size;
    constexpr sampler texSampler;
    float4 gBuffers = normalsAndDepth.sample(texSampler, txCoords);
    float3 n_s = gBuffers.rgb;
    
    float scene_z = gBuffers.a;
    
    float3 n = n_s * 2.0 - 1.0;
    
    float3 v = in.v_view * (scene_z / in.v_view.z);  //position in model space * (gbuffer depth / point depth)
    
    float3 l = lightData->view_light_position.xyz - v; //light position in model space - v
    float n_ls = dot(n, n);
    float v_ls = dot(v, v);
    float l_ls = dot(l, l);
    float3 h = (l * rsqrt(l_ls / v_ls) - v);
    float h_ls = dot(h, h);
    float nl = dot(n, l) * rsqrt(n_ls * l_ls);
    float nh = dot(n, h) * rsqrt(n_ls * h_ls);
    float d_atten = sqrt(l_ls) * 1.0f / lightData->screen_size.x;  //length of l
    float atten = fmax(1.0 - d_atten / lightData->light_color_radius.w, 0.0);
    float diffuse = fmax(nl, 0.0) * atten;
    
    //float4 light = gBuffers.light;
    //float4 light = lightColor.sample(texSampler, txCoords);
    float4 light = float4(0.0);
    light.rgb += lightData->light_color_radius.xyz * diffuse;
    light.a += pow(fmax(nh, 0.0), 32.0) * step(0.0, nl) * atten * 1.0001;
    
    return light;
}
