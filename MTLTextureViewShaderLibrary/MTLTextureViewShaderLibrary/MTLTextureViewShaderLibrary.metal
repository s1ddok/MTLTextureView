//
//  MTLTextureViewShaderLibrary.metal
//  MTLTextureViewShaderLibrary
//
//  Created by Andrey Volodin on 05.09.2018.
//  Copyright © 2018 Andrey Volodin. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct MTLTextureViewVertexOut {
    float4 position [[ position ]];
    float2 uv;
};

vertex MTLTextureViewVertexOut mtlTextureViewVertex(uint vid [[vertex_id]]) {
    MTLTextureViewVertexOut out;
    
    const float2 vertices[] = { float2(-1.0f, 1.0f), float2(-1.0f, -1.0f),
        float2(1.0f, 1.0f), float2(1.0f, -1.0f)
    };
    
    out.position = float4(vertices[vid], 0.0, 1.0);
    float2 uv = vertices[vid];
    uv.y = -uv.y;
    out.uv = fma(uv, 0.5f, 0.5f);
    
    return out;
}

fragment half4 mtlTextureViewFragment(MTLTextureViewVertexOut in [[stage_in]],
                                      texture2d<float, access::sample> tex2d [[texture(0)]],
                                      constant float2& resolution){
    constexpr sampler s(coord::normalized,
                        address::clamp_to_zero,
                        filter::linear);
    
    half4 color = half4(tex2d.sample(s, in.uv));
    return color;
}

