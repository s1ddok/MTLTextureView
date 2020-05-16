#include <metal_stdlib>
using namespace metal;

typedef struct {
    float4 position [[ position ]];
    float2 texCoord;
} FragmentIn;

constant float2 vertices[] = {
    { -1.0f,  1.0f },
    { -1.0f, -1.0f },
    {  1.0f,  1.0f },
    {  1.0f, -1.0f }
};

vertex FragmentIn vertexFunction(constant float4x4& projectionMatrix [[buffer(0)]],
                                 uint vertexID [[ vertex_id ]]) {
    float2 texCoord = vertices[vertexID];
    texCoord.y = -texCoord.y;
    FragmentIn out = {
        projectionMatrix * float4(vertices[vertexID], 0.0, 1.0),
        fma(texCoord, 0.5f, 0.5f)
    };
    return out;
}

fragment float4 fragmentFunction(FragmentIn in [[stage_in]],
                                 texture2d<float, access::sample> sourceTexture [[ texture(0) ]]) {
    constexpr sampler s(coord::normalized,
                        address::clamp_to_zero,
                        filter::linear);
    const auto targetPosition = float3(in.texCoord, 1.0f).xy;
    return sourceTexture.sample(s, targetPosition);
}

