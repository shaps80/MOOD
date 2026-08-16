#include <metal_stdlib>

using namespace metal;

struct PointVertex {
    float4 position [[position]];
    float pointSize [[point_size]];
    half4 color;
};

vertex PointVertex pointVertex(
    uint vertexID [[vertex_id]],
    const device packed_float3 *positions [[buffer(0)]],
    constant float4x4 &viewProjection [[buffer(1)]]
) {
    PointVertex output;
    output.position = viewProjection * float4(positions[vertexID], 1);
    output.pointSize = 1;
    output.color = half4(1);
    return output;
}

fragment half4 pointFragment(PointVertex input [[stage_in]]) {
    return input.color;
}
