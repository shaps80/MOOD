#include <metal_stdlib>

using namespace metal;

struct PointVertex {
    float4 position [[position]];
    float pointSize [[point_size]];
    half4 color;
};

struct PositionPair {
    packed_float3 previous;
    packed_float3 current;
};

vertex PointVertex pointVertex(
    uint vertexID [[vertex_id]],
    const device PositionPair *positions [[buffer(0)]],
    constant float4x4 &viewProjection [[buffer(1)]],
    constant float &interpolation [[buffer(2)]]
) {
    PointVertex output;
    float3 position = mix(
        float3(positions[vertexID].previous),
        float3(positions[vertexID].current),
        interpolation
    );
    output.position = viewProjection * float4(position, 1);
    output.pointSize = 1;
    output.color = half4(1);
    return output;
}

fragment half4 pointFragment(PointVertex input [[stage_in]]) {
    return input.color;
}
