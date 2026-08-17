#include <metal_stdlib>

using namespace metal;

struct CullingBoundsVertex {
    float4 position [[position]];
};

vertex CullingBoundsVertex cullingBoundsVertex(
    uint vertexID [[vertex_id]],
    constant float4x4 &viewProjection [[buffer(0)]],
    constant float2 &bounds [[buffer(1)]]
) {
    constexpr float3 vertices[] = {
        float3(-1, -1, -1), float3( 1, -1, -1),
        float3( 1, -1, -1), float3( 1,  1, -1),
        float3( 1,  1, -1), float3(-1,  1, -1),
        float3(-1,  1, -1), float3(-1, -1, -1),
        float3(-1, -1,  1), float3( 1, -1,  1),
        float3( 1, -1,  1), float3( 1,  1,  1),
        float3( 1,  1,  1), float3(-1,  1,  1),
        float3(-1,  1,  1), float3(-1, -1,  1),
        float3(-1, -1, -1), float3(-1, -1,  1),
        float3( 1, -1, -1), float3( 1, -1,  1),
        float3( 1,  1, -1), float3( 1,  1,  1),
        float3(-1,  1, -1), float3(-1,  1,  1),
    };
    float halfExtent = bounds.x;
    float baseHeight = bounds.y;
    float3 position = vertices[vertexID] * halfExtent;
    position.y += baseHeight + halfExtent;
    CullingBoundsVertex output;
    output.position = viewProjection
        * float4(position, 1);
    return output;
}

fragment half4 cullingBoundsFragment() {
    return half4(1, 1, 0, 1);
}
