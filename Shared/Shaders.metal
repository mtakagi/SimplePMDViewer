//
//  Shaders.metal
//  metal-proj Shared
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


vertex float4 vertexShader(Vertex in [[stage_in]],
                           constant Uniforms & uniforms [[ buffer(1) ]])
{
    float4 position = float4(in.position, 1.0);
    
    return uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
}

fragment float4 fragmentShader()
{
    return float4(0, 0, 0, 1);
}
