#include <metal_stdlib>

using namespace metal;

struct CameraFrustumVertex {
    float4 position [[position]];
};

float3 unprojectFrustumPoint(
    float2 point,
    float depth,
    constant float4x4 &inverseViewProjection
) {
    float4 world = inverseViewProjection * float4(point, depth, 1);
    return world.xyz / world.w;
}

float2 frustumPerimeterPoint(uint edge, float amount) {
    switch (edge) {
    case 0: return float2(mix(-1.0, 1.0, amount), -1.0);
    case 1: return float2(1.0, mix(-1.0, 1.0, amount));
    case 2: return float2(mix(1.0, -1.0, amount), 1.0);
    default: return float2(-1.0, mix(1.0, -1.0, amount));
    }
}

float3 frustumEdgePoint(
    uint edge,
    uint endpoint,
    constant float4x4 &inverseViewProjection
) {
    constexpr float2 corners[] = {
        float2(-1, -1), float2(1, -1),
        float2(1, 1), float2(-1, 1),
    };

    if (edge < 4) {
        uint corner = endpoint == 0 ? edge : (edge + 1) % 4;
        return unprojectFrustumPoint(corners[corner], 0, inverseViewProjection);
    }
    if (edge < 8) {
        uint farEdge = edge - 4;
        uint corner = endpoint == 0 ? farEdge : (farEdge + 1) % 4;
        return unprojectFrustumPoint(corners[corner], 1, inverseViewProjection);
    }

    uint corner = edge - 8;
    return unprojectFrustumPoint(
        corners[corner],
        endpoint == 0 ? 0 : 1,
        inverseViewProjection
    );
}

vertex CameraFrustumVertex cameraFrustumVertex(
    uint vertexID [[vertex_id]],
    constant float4x4 &viewProjection [[buffer(0)]],
    constant float4x4 &inverseViewProjection [[buffer(1)]],
    constant float3 &origin [[buffer(2)]],
    constant uint &isPerspective [[buffer(3)]],
    constant uint &gridDivisions [[buffer(4)]]
) {
    uint rayVertexCount = 4 * (gridDivisions + 1) * 2;
    float3 position;

    if (vertexID < rayVertexCount) {
        uint rayVertex = vertexID;
        uint endpoint = rayVertex % 2;
        uint ray = rayVertex / 2;
        uint edge = ray / (gridDivisions + 1);
        float amount = float(ray % (gridDivisions + 1)) / float(gridDivisions);
        float2 point = frustumPerimeterPoint(edge, amount);
        position = endpoint == 0
            ? (isPerspective != 0
                ? origin
                : unprojectFrustumPoint(point, 0, inverseViewProjection))
            : unprojectFrustumPoint(point, 1, inverseViewProjection);
    } else {
        uint edgeVertex = vertexID - rayVertexCount;
        position = frustumEdgePoint(
            edgeVertex / 2,
            edgeVertex % 2,
            inverseViewProjection
        );
    }

    CameraFrustumVertex output;
    output.position = viewProjection * float4(position, 1);
    return output;
}

fragment half4 cameraFrustumFragment() {
    return half4(0.45h, 0.015h, 0.01h, 0.55h);
}
