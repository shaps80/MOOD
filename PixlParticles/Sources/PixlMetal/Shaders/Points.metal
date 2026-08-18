#include <metal_stdlib>

using namespace metal;

struct PointVertex {
    float4 position [[position]];
    float pointSize [[point_size]];
    half4 color;
};

struct PositionBatch {
    float4 x;
    float4 y;
    float4 z;
};

struct ColorBatch {
    float4 red;
    float4 green;
    float4 blue;
    float4 alpha;
};

struct CameraFrame {
    float4x4 viewProjection;
    float4 position;
    float4 right;
    float4 up;
    float4 viewport;
};

struct BillboardConfiguration {
    float4 values;
    uint4 modes;
};

struct FrustumPlanes {
    float4 left;
    float4 right;
    float4 bottom;
    float4 top;
    float4 near;
    float4 far;
};

struct BillboardVertex {
    float4 position [[position]];
    half4 color;
};

static float4 particleColor(
    const device ColorBatch *colors,
    uint particleIndex
) {
    uint batch = particleIndex / 4;
    uint lane = particleIndex % 4;
    return float4(
        colors[batch].red[lane],
        colors[batch].green[lane],
        colors[batch].blue[lane],
        colors[batch].alpha[lane]
    );
}

static float3 particlePosition(
    const device PositionBatch *positions,
    uint particleIndex
) {
    uint batch = particleIndex / 4;
    uint lane = particleIndex % 4;
    return float3(
        positions[batch].x[lane],
        positions[batch].y[lane],
        positions[batch].z[lane]
    );
}

static ulong particleID(
    const device ulong4 *ids,
    uint particleIndex
) {
    return ids[particleIndex / 4][particleIndex % 4];
}

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

static bool sphereIntersectsFrustum(
    float3 position,
    float radius,
    constant FrustumPlanes &frustum
) {
    float4 center = float4(position, 1);
    float4 planes[6] = {
        frustum.left,
        frustum.right,
        frustum.bottom,
        frustum.top,
        frustum.near,
        frustum.far,
    };
    for (uint index = 0; index < 6; ++index) {
        float4 plane = planes[index];
        if (dot(plane, center) < -radius) {
            return false;
        }
    }
    return true;
}

static bool pointInsideFrustum(
    float3 position,
    float4x4 viewProjection
) {
    float4 clip = viewProjection * float4(position, 1);
    return clip.w > 0
        && clip.x >= -clip.w && clip.x <= clip.w
        && clip.y >= -clip.w && clip.y <= clip.w
        && clip.z >= 0 && clip.z <= clip.w;
}

static bool screenBillboardIntersectsFrustum(
    float3 position,
    float radius,
    float4x4 viewProjection,
    uint2 viewport
) {
    float4 clip = viewProjection * float4(position, 1);
    if (clip.w <= 0) return false;
    float2 expansion = float2(2 * radius)
        / max(float2(viewport), float2(1));
    return clip.x >= -clip.w * (1 + expansion.x)
        && clip.x <= clip.w * (1 + expansion.x)
        && clip.y >= -clip.w * (1 + expansion.y)
        && clip.y <= clip.w * (1 + expansion.y)
        && clip.z >= 0
        && clip.z <= clip.w;
}

kernel void classifyAndScanVisibility(
    const device PositionBatch *previousPositions [[buffer(0)]],
    device uint *localOffsets [[buffer(1)]],
    device uint *blockSums [[buffer(2)]],
    constant float4x4 &viewProjection [[buffer(3)]],
    constant float &interpolation [[buffer(4)]],
    constant uint &particleCount [[buffer(5)]],
    constant float2 &cullingBounds [[buffer(6)]],
    constant uint &hasCullingBounds [[buffer(7)]],
    const device PositionBatch *currentPositions [[buffer(8)]],
    constant float &billboardRadius [[buffer(9)]],
    constant uint &cullingMode [[buffer(10)]],
    constant uint2 &viewport [[buffer(11)]],
    constant FrustumPlanes &frustum [[buffer(12)]],
    uint index [[thread_position_in_grid]],
    uint lane [[thread_index_in_threadgroup]],
    uint block [[threadgroup_position_in_grid]],
    uint blockSize [[threads_per_threadgroup]]
) {
    threadgroup uint scan[256];
    uint visible = 0;

    if (index < particleCount) {
        float3 position = mix(
            particlePosition(previousPositions, index),
            particlePosition(currentPositions, index),
            interpolation
        );
        float halfExtent = cullingBounds.x;
        float baseHeight = cullingBounds.y;
        bool insideBounds = !hasCullingBounds || (
            abs(position.x) <= halfExtent
            && abs(position.z) <= halfExtent
            && position.y >= baseHeight
            && position.y <= baseHeight + halfExtent * 2.0f
        );
        bool insideFrustum;
        if (cullingMode == 0) {
            insideFrustum = pointInsideFrustum(position, viewProjection);
        } else if (cullingMode == 1) {
            insideFrustum = sphereIntersectsFrustum(
                position,
                billboardRadius,
                frustum
            );
        } else {
            insideFrustum = screenBillboardIntersectsFrustum(
                position,
                billboardRadius,
                viewProjection,
                viewport
            );
        }
        visible = insideBounds && insideFrustum;
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
    device DrawArguments &arguments [[buffer(1)]],
    constant uint &cullingMode [[buffer(2)]]
) {
    bool isPoint = cullingMode == 0;
    arguments.vertexCount = isPoint ? total[0] : 4;
    arguments.instanceCount = isPoint ? 1 : total[0];
    arguments.vertexStart = 0;
    arguments.baseInstance = 0;
}

kernel void captureVisibleCount(
    const device DrawArguments &arguments [[buffer(0)]],
    device uint &count [[buffer(1)]],
    constant uint &renderMode [[buffer(2)]]
) {
    count = renderMode == 0
        ? arguments.vertexCount
        : arguments.instanceCount;
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
    const device PositionBatch *previousPositions [[buffer(0)]],
    const device uint *visibleIndices [[buffer(1)]],
    const device DrawArguments &visibleArguments [[buffer(2)]],
    device atomic_uint *tileCounts [[buffer(3)]],
    device uint *tileIndices [[buffer(4)]],
    constant float4x4 &viewProjection [[buffer(5)]],
    constant float &interpolation [[buffer(6)]],
    constant PointLODConfiguration &configuration [[buffer(7)]],
    const device PositionBatch *currentPositions [[buffer(8)]],
    uint index [[thread_position_in_grid]]
) {
    if (index >= visibleArguments.vertexCount) return;
    uint particleIndex = visibleIndices[index];
    float3 position = mix(
        particlePosition(previousPositions, particleIndex),
        particlePosition(currentPositions, particleIndex),
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
    const device ulong4 *ids [[buffer(0)]],
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
            || pointLODHash(particleID(ids, particleIndex)) < threshold;
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
    const device PositionBatch *previousPositions [[buffer(0)]],
    const device uint *visibleIndices [[buffer(1)]],
    constant float4x4 &viewProjection [[buffer(2)]],
    constant float &interpolation [[buffer(3)]],
    const device ColorBatch *colors [[buffer(6)]],
    const device PositionBatch *currentPositions [[buffer(7)]]
) {
    uint particleIndex = visibleIndices[vertexID];
    PointVertex output;
    float3 position = mix(
        particlePosition(previousPositions, particleIndex),
        particlePosition(currentPositions, particleIndex),
        interpolation
    );
    output.position = viewProjection * float4(position, 1);
    output.pointSize = 1;
    output.color = half4(particleColor(colors, particleIndex));
    return output;
}

vertex PointVertex pointLODVertex(
    uint vertexID [[vertex_id]],
    const device PositionBatch *previousPositions [[buffer(0)]],
    const device uint *visibleIndices [[buffer(1)]],
    constant float4x4 &viewProjection [[buffer(2)]],
    constant float &interpolation [[buffer(3)]],
    const device uint *lodVisibleIndices [[buffer(4)]],
    const device PointLODState &state [[buffer(5)]],
    const device ColorBatch *colors [[buffer(6)]],
    const device PositionBatch *currentPositions [[buffer(7)]]
) {
    uint particleIndex = state.active
        ? lodVisibleIndices[vertexID]
        : visibleIndices[vertexID];
    PointVertex output;
    float3 position = mix(
        particlePosition(previousPositions, particleIndex),
        particlePosition(currentPositions, particleIndex),
        interpolation
    );
    output.position = viewProjection * float4(position, 1);
    output.pointSize = 1;
    output.color = half4(particleColor(colors, particleIndex));
    return output;
}

static float3 safeNormalize(float3 value, float3 fallback) {
    float magnitudeSquared = length_squared(value);
    return magnitudeSquared > 1e-8f
        ? value * rsqrt(magnitudeSquared)
        : fallback;
}

static void billboardBasis(
    float3 center,
    constant CameraFrame &camera,
    uint facing,
    thread float3 &right,
    thread float3 &up
) {
    right = camera.right.xyz;
    up = camera.up.xyz;
    if (facing == 1) return;

    float3 normal = safeNormalize(
        camera.position.xyz - center,
        cross(camera.right.xyz, camera.up.xyz)
    );
    float3 referenceUp = facing == 2
        ? float3(0, 1, 0)
        : camera.up.xyz;
    right = safeNormalize(cross(referenceUp, normal), camera.right.xyz);
    up = safeNormalize(cross(normal, right), referenceUp);
}

vertex BillboardVertex billboardVertex(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    const device PositionBatch *previousPositions [[buffer(0)]],
    const device uint *visibleIndices [[buffer(1)]],
    constant CameraFrame &camera [[buffer(2)]],
    constant float &interpolation [[buffer(3)]],
    constant BillboardConfiguration &configuration [[buffer(4)]],
    const device ColorBatch *colors [[buffer(6)]],
    const device PositionBatch *currentPositions [[buffer(7)]]
) {
    uint particleIndex = visibleIndices[instanceID];
    float3 center = mix(
        particlePosition(previousPositions, particleIndex),
        particlePosition(currentPositions, particleIndex),
        interpolation
    );
    float2 corner = float2(
        (vertexID & 1) == 0 ? -0.5f : 0.5f,
        (vertexID & 2) == 0 ? -0.5f : 0.5f
    );
    float sine = sin(configuration.values.z);
    float cosine = cos(configuration.values.z);
    float2 local = corner * configuration.values.xy;
    local = float2(
        local.x * cosine - local.y * sine,
        local.x * sine + local.y * cosine
    );

    BillboardVertex output;
    if (configuration.modes.x == 1) {
        output.position = camera.viewProjection * float4(center, 1);
        output.position.xy += local
            * float2(camera.viewport.z * 2, camera.viewport.w * 2)
            * output.position.w;
    } else {
        float3 right;
        float3 up;
        billboardBasis(
            center,
            camera,
            configuration.modes.y,
            right,
            up
        );
        output.position = camera.viewProjection
            * float4(center + right * local.x + up * local.y, 1);
    }
    output.color = half4(particleColor(colors, particleIndex));
    return output;
}

fragment half4 pointFragment(PointVertex input [[stage_in]]) {
    return input.color;
}

fragment half4 billboardFragment(BillboardVertex input [[stage_in]]) {
    return input.color;
}
