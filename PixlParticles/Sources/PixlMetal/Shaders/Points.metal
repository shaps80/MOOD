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

struct DispatchArguments {
    uint threadgroupsX;
    uint threadgroupsY;
    uint threadgroupsZ;
};

struct PointLODConfiguration {
    uint activationCount;
    uint maximumVisibleCount;
    uint tileSize;
    uint targetPointsPerPixel;
    uint viewportWidth;
    uint viewportHeight;
    uint tileColumns;
    uint tileCount;
};

struct PointLODState {
    uint active;
    uint globalThreshold;
    uint reserved1;
    uint reserved2;
};

static uint pointLODTile(
    float4 clip,
    constant PointLODConfiguration &configuration
) {
    float2 ndc = clip.xy / clip.w;
    float2 pixel = float2(
        (ndc.x * 0.5f + 0.5f) * float(configuration.viewportWidth),
        (ndc.y * 0.5f + 0.5f) * float(configuration.viewportHeight)
    );
    uint x = min(uint(pixel.x) / configuration.tileSize,
                 configuration.tileColumns - 1);
    uint rows = configuration.tileCount / configuration.tileColumns;
    uint y = min(uint(pixel.y) / configuration.tileSize, rows - 1);
    return y * configuration.tileColumns + x;
}

static uint pointLODHash(ulong value) {
    uint hash = uint(value) ^ uint(value >> 32);
    hash ^= hash >> 16;
    hash *= 0x85EBCA6Bu;
    hash ^= hash >> 13;
    hash *= 0xC2B2AE35u;
    return hash ^ (hash >> 16);
}

kernel void classifyAndScanVisibility(
    const device PositionPair *positions [[buffer(0)]],
    device uint *localOffsets [[buffer(1)]],
    device uint *blockSums [[buffer(2)]],
    constant float4x4 &viewProjection [[buffer(3)]],
    constant float &interpolation [[buffer(4)]],
    constant uint &particleCount [[buffer(5)]],
    constant float2 &cullingBounds [[buffer(6)]],
    constant uint &hasCullingBounds [[buffer(7)]],
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
        float halfExtent = cullingBounds.x;
        float baseHeight = cullingBounds.y;
        bool insideBounds = !hasCullingBounds || (
            abs(position.x) <= halfExtent
            && abs(position.z) <= halfExtent
            && position.y >= baseHeight
            && position.y <= baseHeight + halfExtent * 2.0f
        );
        visible = insideBounds && clip.w > 0 &&
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

kernel void scanBlockSums(
    const device uint *input [[buffer(0)]],
    device uint *offsets [[buffer(1)]],
    device uint *groupSums [[buffer(2)]],
    constant uint &count [[buffer(3)]],
    uint index [[thread_position_in_grid]],
    uint lane [[thread_index_in_threadgroup]],
    uint group [[threadgroup_position_in_grid]],
    uint blockSize [[threads_per_threadgroup]]
) {
    threadgroup uint scan[256];
    uint value = index < count ? input[index] : 0;
    scan[lane] = value;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint offset = 1; offset < blockSize; offset <<= 1) {
        uint previous = lane >= offset ? scan[lane - offset] : 0;
        threadgroup_barrier(mem_flags::mem_threadgroup);
        scan[lane] += previous;
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (index < count) offsets[index] = scan[lane] - value;
    if (lane == blockSize - 1) groupSums[group] = scan[lane];
}

kernel void addScannedBlockOffsets(
    device uint *offsets [[buffer(0)]],
    const device uint *parentOffsets [[buffer(1)]],
    constant uint &count [[buffer(2)]],
    uint index [[thread_position_in_grid]]
) {
    if (index < count) offsets[index] += parentOffsets[index / 256];
}

kernel void finishVisibilityScan(
    const device uint *total [[buffer(0)]],
    device DrawArguments &arguments [[buffer(1)]]
) {
    arguments.vertexCount = total[0];
    arguments.instanceCount = 1;
    arguments.vertexStart = 0;
    arguments.baseInstance = 0;
}

kernel void captureVisibleCount(
    const device DrawArguments &arguments [[buffer(0)]],
    device uint &count [[buffer(1)]]
) {
    count = arguments.vertexCount;
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

kernel void preparePointLOD(
    const device DrawArguments &visibleArguments [[buffer(0)]],
    device DrawArguments &drawArguments [[buffer(1)]],
    device DispatchArguments &workArguments [[buffer(2)]],
    device DispatchArguments &clearArguments [[buffer(3)]],
    device PointLODState &state [[buffer(4)]],
    constant PointLODConfiguration &configuration [[buffer(5)]]
) {
    uint visibleCount = visibleArguments.vertexCount;
    bool active = visibleCount > 0
        && visibleCount >= configuration.activationCount;
    state.active = active;
    state.globalThreshold = configuration.maximumVisibleCount >= visibleCount
        ? UINT_MAX
        : uint(ulong(configuration.maximumVisibleCount)
            * ulong(UINT_MAX) / ulong(visibleCount));
    drawArguments.vertexCount = visibleCount;
    drawArguments.instanceCount = 1;
    drawArguments.vertexStart = 0;
    drawArguments.baseInstance = 0;
    workArguments.threadgroupsX = active ? (visibleCount + 255) / 256 : 0;
    workArguments.threadgroupsY = 1;
    workArguments.threadgroupsZ = 1;
    clearArguments.threadgroupsX = active
        ? (configuration.tileCount + 255) / 256
        : 0;
    clearArguments.threadgroupsY = 1;
    clearArguments.threadgroupsZ = 1;
}

kernel void clearPointLODTiles(
    device atomic_uint *tileCounts [[buffer(0)]],
    constant uint &tileCount [[buffer(1)]],
    uint index [[thread_position_in_grid]]
) {
    if (index < tileCount) {
        atomic_store_explicit(&tileCounts[index], 0, memory_order_relaxed);
    }
}

kernel void countPointLODTiles(
    const device PositionPair *positions [[buffer(0)]],
    const device uint *visibleIndices [[buffer(1)]],
    const device DrawArguments &visibleArguments [[buffer(2)]],
    device atomic_uint *tileCounts [[buffer(3)]],
    device uint *tileIndices [[buffer(4)]],
    constant float4x4 &viewProjection [[buffer(5)]],
    constant float &interpolation [[buffer(6)]],
    constant PointLODConfiguration &configuration [[buffer(7)]],
    uint index [[thread_position_in_grid]]
) {
    if (index >= visibleArguments.vertexCount) return;
    uint particleIndex = visibleIndices[index];
    float3 position = mix(
        float3(positions[particleIndex].previous),
        float3(positions[particleIndex].current),
        interpolation
    );
    uint tile = pointLODTile(
        viewProjection * float4(position, 1),
        configuration
    );
    tileIndices[index] = tile;
    atomic_fetch_add_explicit(&tileCounts[tile], 1, memory_order_relaxed);
}

kernel void preparePointLODThresholds(
    const device atomic_uint *tileCounts [[buffer(0)]],
    device uint *tileThresholds [[buffer(1)]],
    constant PointLODConfiguration &configuration [[buffer(2)]],
    uint index [[thread_position_in_grid]]
) {
    if (index >= configuration.tileCount) return;
    uint count = atomic_load_explicit(&tileCounts[index], memory_order_relaxed);
    ulong tilePixels = ulong(configuration.tileSize)
        * ulong(configuration.tileSize);
    ulong desired = tilePixels
        * ulong(configuration.targetPointsPerPixel) >> 16;
    tileThresholds[index] = desired >= count
        ? UINT_MAX
        : uint(desired * ulong(UINT_MAX) / ulong(count));
}

kernel void classifyPointLOD(
    const device ulong *ids [[buffer(0)]],
    const device uint *visibleIndices [[buffer(1)]],
    const device DrawArguments &visibleArguments [[buffer(2)]],
    const device uint *tileThresholds [[buffer(3)]],
    device uint *localOffsets [[buffer(4)]],
    device uint *blockSums [[buffer(5)]],
    const device PointLODState &state [[buffer(6)]],
    uint index [[thread_position_in_grid]],
    uint lane [[thread_index_in_threadgroup]],
    uint block [[threadgroup_position_in_grid]],
    uint blockSize [[threads_per_threadgroup]]
) {
    threadgroup uint scan[256];
    uint retained = 0;
    uint visibleCount = visibleArguments.vertexCount;

    if (index < visibleCount) {
        uint particleIndex = visibleIndices[index];
        uint tile = localOffsets[index];
        uint threshold = min(tileThresholds[tile], state.globalThreshold);
        retained = threshold == UINT_MAX
            || pointLODHash(ids[particleIndex]) < threshold;
    }

    scan[lane] = retained;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint offset = 1; offset < blockSize; offset <<= 1) {
        uint value = lane >= offset ? scan[lane - offset] : 0;
        threadgroup_barrier(mem_flags::mem_threadgroup);
        scan[lane] += value;
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (index < visibleCount) {
        localOffsets[index] = retained ? scan[lane] - 1 : UINT_MAX;
    }
    if (lane == blockSize - 1) {
        blockSums[block] = scan[lane];
    }
}

kernel void finishPointLODScan(
    const device uint *total [[buffer(0)]],
    device DrawArguments &drawArguments [[buffer(1)]],
    const device PointLODState &state [[buffer(2)]],
    constant uint &maximumVisibleCount [[buffer(3)]]
) {
    if (!state.active) return;
    drawArguments.vertexCount = min(total[0], maximumVisibleCount);
}

kernel void scanPointLODBlockSums(
    const device uint *input [[buffer(0)]],
    device uint *offsets [[buffer(1)]],
    device uint *groupSums [[buffer(2)]],
    const device DrawArguments &visibleArguments [[buffer(3)]],
    const device PointLODState &state [[buffer(4)]],
    constant uint &divisor [[buffer(5)]],
    uint index [[thread_position_in_grid]],
    uint lane [[thread_index_in_threadgroup]],
    uint group [[threadgroup_position_in_grid]],
    uint blockSize [[threads_per_threadgroup]]
) {
    if (!state.active) return;
    uint count = (visibleArguments.vertexCount - 1) / divisor + 1;
    threadgroup uint scan[256];
    uint value = index < count ? input[index] : 0;
    scan[lane] = value;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint offset = 1; offset < blockSize; offset <<= 1) {
        uint previous = lane >= offset ? scan[lane - offset] : 0;
        threadgroup_barrier(mem_flags::mem_threadgroup);
        scan[lane] += previous;
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (index < count) offsets[index] = scan[lane] - value;
    if (lane == blockSize - 1) groupSums[group] = scan[lane];
}

kernel void addPointLODScanOffsets(
    device uint *offsets [[buffer(0)]],
    const device uint *parentOffsets [[buffer(1)]],
    const device DrawArguments &visibleArguments [[buffer(2)]],
    const device PointLODState &state [[buffer(3)]],
    constant uint &divisor [[buffer(4)]],
    uint index [[thread_position_in_grid]]
) {
    if (!state.active) return;
    uint count = (visibleArguments.vertexCount - 1) / divisor + 1;
    if (index < count) offsets[index] += parentOffsets[index / 256];
}

kernel void scatterPointLOD(
    const device uint *localOffsets [[buffer(0)]],
    const device uint *blockOffsets [[buffer(1)]],
    const device uint *visibleIndices [[buffer(2)]],
    device uint *lodVisibleIndices [[buffer(3)]],
    const device DrawArguments &visibleArguments [[buffer(4)]],
    constant uint &maximumVisibleCount [[buffer(5)]],
    uint index [[thread_position_in_grid]]
) {
    if (index >= visibleArguments.vertexCount) return;
    uint localOffset = localOffsets[index];
    if (localOffset == UINT_MAX) return;
    uint destination = blockOffsets[index / 256] + localOffset;
    if (destination < maximumVisibleCount) {
        lodVisibleIndices[destination] = visibleIndices[index];
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

vertex PointVertex pointLODVertex(
    uint vertexID [[vertex_id]],
    const device PositionPair *positions [[buffer(0)]],
    const device uint *visibleIndices [[buffer(1)]],
    constant float4x4 &viewProjection [[buffer(2)]],
    constant float &interpolation [[buffer(3)]],
    const device uint *lodVisibleIndices [[buffer(4)]],
    const device PointLODState &state [[buffer(5)]]
) {
    uint particleIndex = state.active
        ? lodVisibleIndices[vertexID]
        : visibleIndices[vertexID];
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
