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

struct DrawArguments {
    uint vertexCount;
    uint instanceCount;
    uint vertexStart;
    uint baseInstance;
};

kernel void classifyAndScanVisibility(
    const device PositionPair *positions [[buffer(0)]],
    device uint *localOffsets [[buffer(1)]],
    device uint *blockSums [[buffer(2)]],
    constant float4x4 &viewProjection [[buffer(3)]],
    constant float &interpolation [[buffer(4)]],
    constant uint &particleCount [[buffer(5)]],
    uint index [[thread_position_in_grid]],
    uint lane [[thread_index_in_threadgroup]],
    uint block [[threadgroup_position_in_grid]],
    uint blockSize [[threads_per_threadgroup]]
) {
    threadgroup uint scan[256];
    uint visible = 0;

    if (index < particleCount) {
        float3 position = mix(
            float3(positions[index].previous),
            float3(positions[index].current),
            interpolation
        );
        float4 clip = viewProjection * float4(position, 1);
        visible = clip.w > 0 &&
            clip.x >= -clip.w && clip.x <= clip.w &&
            clip.y >= -clip.w && clip.y <= clip.w &&
            clip.z >= 0 && clip.z <= clip.w;
    }

    scan[lane] = visible;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint offset = 1; offset < blockSize; offset <<= 1) {
        uint value = lane >= offset ? scan[lane - offset] : 0;
        threadgroup_barrier(mem_flags::mem_threadgroup);
        scan[lane] += value;
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (index < particleCount) {
        localOffsets[index] = visible ? scan[lane] - 1 : UINT_MAX;
    }
    if (lane == blockSize - 1) {
        blockSums[block] = scan[lane];
    }
}

kernel void scanVisibilityBlocks(
    const device uint *blockSums [[buffer(0)]],
    device uint *blockOffsets [[buffer(1)]],
    device DrawArguments &arguments [[buffer(2)]],
    constant uint &blockCount [[buffer(3)]]
) {
    uint total = 0;
    for (uint block = 0; block < blockCount; ++block) {
        blockOffsets[block] = total;
        total += blockSums[block];
    }

    arguments.vertexCount = total;
    arguments.instanceCount = 1;
    arguments.vertexStart = 0;
    arguments.baseInstance = 0;
}

kernel void scatterVisibleIndices(
    const device uint *localOffsets [[buffer(0)]],
    const device uint *blockOffsets [[buffer(1)]],
    device uint *visibleIndices [[buffer(2)]],
    constant uint &particleCount [[buffer(3)]],
    uint index [[thread_position_in_grid]]
) {
    if (index >= particleCount) {
        return;
    }

    uint localOffset = localOffsets[index];
    if (localOffset != UINT_MAX) {
        visibleIndices[blockOffsets[index / 256] + localOffset] = index;
    }
}

vertex PointVertex pointVertex(
    uint vertexID [[vertex_id]],
    const device PositionPair *positions [[buffer(0)]],
    const device uint *visibleIndices [[buffer(1)]],
    constant float4x4 &viewProjection [[buffer(2)]],
    constant float &interpolation [[buffer(3)]]
) {
    uint particleIndex = visibleIndices[vertexID];
    PointVertex output;
    float3 position = mix(
        float3(positions[particleIndex].previous),
        float3(positions[particleIndex].current),
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
