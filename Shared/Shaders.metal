//
//  Shaders.metal
//  SimplePMDViewer Shared
//
//  Created by mtakagi on 2025/10/20.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

#import "ShaderTypes.h"

using namespace metal;

typedef struct
{
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 uv [[attribute(2)]];
} Vertex;

typedef struct
{
    float4 position [[position]];
    float2 texCoord;
} ColorInOut;

vertex ColorInOut vertexShader(Vertex in [[stage_in]],
                           constant Uniforms & uniforms [[ buffer(1) ]])
{
    ColorInOut out;
    
    float4 position = float4(in.position, 1.0);
    
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.texCoord = in.uv;
    
    return out;
}

fragment float4 fragmentShader(ColorInOut in [[stage_in]],
                               texture2d<float> texture [[ texture(0) ]],
                               constant float4 & diffuse [[ buffer(0) ]])
{
    constexpr sampler sampler(mag_filter::linear, min_filter::linear);
    
    if (is_null_texture(texture)) {
        return diffuse;
    }
    
    return diffuse * texture.sample(sampler, in.texCoord);
}
