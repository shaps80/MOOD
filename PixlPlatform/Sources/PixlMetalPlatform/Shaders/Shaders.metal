#include <metal_stdlib>
using namespace metal;

struct VertexOutput {
    float4 position [[position]];
    float4 color;
    float2 textureCoordinate;
};

struct VertexInput {
    float2 position [[attribute(0)]];
    float4 color [[attribute(1)]];
    float2 textureCoordinate [[attribute(2)]];
};

struct PrimitiveParameters {
    float3x3 transform;
    float2 textureOrigin;
    float2 textureScale;
};

vertex VertexOutput pixlVertex(
    VertexInput input [[stage_in]],
    constant PrimitiveParameters &parameters [[buffer(1)]]
) {
    float3 position = parameters.transform * float3(input.position, 1.0);
    return {
        float4(position.xy, 0.0, 1.0),
        input.color,
        parameters.textureOrigin
            + input.textureCoordinate * parameters.textureScale
    };
}

fragment float4 pixlFragment(
    VertexOutput input [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    sampler textureSampler [[sampler(0)]]
) {
    return texture.sample(textureSampler, input.textureCoordinate)
        * input.color;
}
