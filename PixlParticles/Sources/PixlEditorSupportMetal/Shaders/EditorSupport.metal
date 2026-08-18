#include <metal_stdlib>

using namespace metal;

struct EditorGuideUniforms {
    float4x4 viewProjection;
    float4 ground;
    float4x4 inverseFrustumViewProjection;
    float4 frustumOrigin;
    uint4 counts;
};

struct EditorVertex {
    float4 position [[position]];
    float4 color;
};

float3 editorUnproject(
    float2 point,
    float depth,
    constant float4x4 &inverseViewProjection
) {
    float4 world = inverseViewProjection * float4(point, depth, 1);
    return world.xyz / world.w;
}

float2 editorFrustumPerimeterPoint(uint edge, float amount) {
    switch (edge) {
    case 0: return float2(mix(-1.0, 1.0, amount), -1.0);
    case 1: return float2(1.0, mix(-1.0, 1.0, amount));
    case 2: return float2(mix(1.0, -1.0, amount), 1.0);
    default: return float2(-1.0, mix(1.0, -1.0, amount));
    }
}

vertex EditorVertex editorGuideVertex(
    uint vertexID [[vertex_id]],
    constant EditorGuideUniforms &uniforms [[buffer(0)]]
) {
    uint groundVertexCount = uniforms.counts.x;
    EditorVertex output;

    if (vertexID < groundVertexCount) {
        float height = uniforms.ground.x;
        float extent = uniforms.ground.y;
        float spacing = uniforms.ground.z;
        float3 world;
        if (uniforms.counts.y == 0) {
            uint lineCount = uint(extent * 2.0f / spacing) + 1;
            uint line = vertexID / 2;
            uint endpoint = vertexID & 1;
            float coordinate = -extent + float(line % lineCount) * spacing;
            float along = endpoint == 0 ? -extent : extent;
            world = line < lineCount
                ? float3(along, height, coordinate)
                : float3(coordinate, height, along);
        } else {
            float x = vertexID == 0 ? -extent : extent;
            world = float3(x, height, 0);
        }
        constexpr float alpha = 0.2;
        constexpr float linearGrey = 0.21404114;
        output.position = uniforms.viewProjection * float4(world, 1);
        output.color = float4(float3(linearGrey * alpha), alpha);
        return output;
    }

    uint rayVertex = vertexID - groundVertexCount;
    uint endpoint = rayVertex % 2;
    uint ray = rayVertex / 2;
    uint divisions = uniforms.counts.w;
    uint edge = ray / (divisions + 1);
    float amount = float(ray % (divisions + 1)) / float(divisions);
    float2 point = editorFrustumPerimeterPoint(edge, amount);
    float3 world = endpoint == 0
        ? (uniforms.counts.z != 0
            ? uniforms.frustumOrigin.xyz
            : editorUnproject(
                point,
                0,
                uniforms.inverseFrustumViewProjection
            ))
        : editorUnproject(point, 1, uniforms.inverseFrustumViewProjection);
    output.position = uniforms.viewProjection * float4(world, 1);
    output.color = float4(0.45, 0.015, 0.01, 0.55);
    return output;
}

fragment half4 editorGuideFragment(EditorVertex input [[stage_in]]) {
    return half4(input.color);
}

struct EditorWireVolumeInstance {
    float4x4 transform;
    float4 color;
};

vertex EditorVertex editorWireVolumeVertex(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    constant float4x4 &viewProjection [[buffer(0)]],
    constant EditorWireVolumeInstance *instances [[buffer(1)]]
) {
    constexpr float3 vertices[] = {
        float3(-1, -1, 0), float3( 1, -1, 0),
        float3( 1, -1, 0), float3( 1,  1, 0),
        float3( 1,  1, 0), float3(-1,  1, 0),
        float3(-1,  1, 0), float3(-1, -1, 0),
        float3(-1, -1, 1), float3( 1, -1, 1),
        float3( 1, -1, 1), float3( 1,  1, 1),
        float3( 1,  1, 1), float3(-1,  1, 1),
        float3(-1,  1, 1), float3(-1, -1, 1),
        float3(-1, -1, 0), float3(-1, -1, 1),
        float3( 1, -1, 0), float3( 1, -1, 1),
        float3( 1,  1, 0), float3( 1,  1, 1),
        float3(-1,  1, 0), float3(-1,  1, 1),
    };
    EditorWireVolumeInstance instance = instances[instanceID];
    float4 world = instance.transform * float4(vertices[vertexID], 1);
    world /= world.w;
    EditorVertex output;
    output.position = viewProjection * float4(world.xyz, 1);
    output.color = instance.color;
    return output;
}

fragment half4 editorWireVolumeFragment(EditorVertex input [[stage_in]]) {
    return half4(input.color);
}
