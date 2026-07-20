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

struct SpriteVertexInput {
    float2 position [[attribute(0)]];
    float2 textureCoordinate [[attribute(2)]];
    float2 transformX [[attribute(3)]];
    float2 transformY [[attribute(4)]];
    float2 translation [[attribute(5)]];
    float2 textureOrigin [[attribute(6)]];
    float2 textureScale [[attribute(7)]];
    float4 tint [[attribute(8)]];
};

struct SpriteViewParameters {
    float3x3 projection;
};

vertex VertexOutput pixlSpriteVertex(
    SpriteVertexInput input [[stage_in]],
    constant SpriteViewParameters &view [[buffer(2)]]
) {
    float2 world = input.transformX * input.position.x
        + input.transformY * input.position.y
        + input.translation;
    float3 projected = view.projection * float3(world, 1.0);
    return {
        float4(projected.xy, 0.0, 1.0),
        input.tint,
        input.textureOrigin + input.textureCoordinate * input.textureScale
    };
}
