//
//  Shaders.metal
//  metal-proj Shared
//
//  Created by mtakagi on 2025/10/20.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
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
    float3 normal;
    float2 texCoord;
} ColorInOut;

vertex ColorInOut vertexShader(Vertex in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(1) ]])
{
    ColorInOut out;

    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    
    // 【修正】法線（Normal）もモデルの回転に合わせて回す！
    out.normal = normalize((uniforms.modelViewMatrix * float4(in.normal, 0.0)).xyz);
    out.texCoord = in.uv;

    return out;
}

fragment float4 fragmentShader(ColorInOut in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(1) ]],
                               texture2d<float> colorTexture [[texture(0)]],
                               constant float4 & diffue [[ buffer(2) ]],
                               constant float4 & ambient [[ buffer(3) ]])
{
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    // 全てのパーツにテクスチャ（最低でもダミーの白）が貼られている前提になる
    float4 texColor = colorTexture.sample(textureSampler, in.texCoord);
    float finalAlpha = diffue.a * texColor.a;
    
    // 目や髪の毛の本当に透明な部分だけがここで捨てられる（顔の皮膚はAlpha 1.0なので生き残る！）
    if (finalAlpha < 0.05) {
        discard_fragment();
    }
    
    float3 light = normalize(float3(0.5, 0.5, 1.0));
    float brightness = max(0.0, dot(in.normal, light));
    
    float3 finalRGB = (diffue.rgb * brightness + ambient.rgb) * texColor.rgb;
#ifdef DEBUG
    return float4(texColor.a, texColor.a, texColor.a, 1);
#else
    return float4(finalRGB, finalAlpha);
#endif
}
