#include <metal_stdlib>

using namespace metal;

struct GroundPlaneUniforms {
    float4x4 viewProjection;
    float4 dimensions;
};

struct GroundPlaneVertex {
    float4 position [[position]];
};

vertex GroundPlaneVertex groundPlaneGridVertex(
    uint vertexID [[vertex_id]],
    constant GroundPlaneUniforms &uniforms [[buffer(0)]]
) {
    float height = uniforms.dimensions.x;
    float extent = uniforms.dimensions.y;
    float spacing = uniforms.dimensions.z;
    uint lineCount = uint(extent * 2.0f / spacing) + 1;
    uint line = vertexID / 2;
    uint endpoint = vertexID & 1;
    float coordinate = -extent + float(line % lineCount) * spacing;
    float along = endpoint == 0 ? -extent : extent;
    float3 world = line < lineCount
        ? float3(along, height, coordinate)
        : float3(coordinate, height, along);

    GroundPlaneVertex output;
    output.position = uniforms.viewProjection * float4(world, 1);
    return output;
}

vertex GroundPlaneVertex groundPlaneHorizonVertex(
    uint vertexID [[vertex_id]],
    constant GroundPlaneUniforms &uniforms [[buffer(0)]]
) {
    float x = vertexID == 0
        ? -uniforms.dimensions.y
        : uniforms.dimensions.y;
    GroundPlaneVertex output;
    output.position = uniforms.viewProjection
        * float4(x, uniforms.dimensions.x, 0, 1);
    return output;
}

fragment half4 groundPlaneFragment() {
    constexpr half alpha = 0.2h;
    constexpr half linearGrey = 0.21404114h;
    return half4(half3(linearGrey * alpha), alpha);
}
