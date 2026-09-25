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
    const device ushort *indices,
    const device float4 *palette,
    uint particleIndex
) {
    return palette[indices[particleIndex]];
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

static float3 interpolatedPosition(
    const device PositionBatch *positions,
    const device uint *displacements,
    float displacementScale,
    uint particleIndex,
    float interpolation
) {
    uint word = displacements[particleIndex];
    int3 components = int3(
        as_type<int>(word << 22) >> 22,
        as_type<int>(word << 12) >> 22,
        as_type<int>(word << 2) >> 22
    );
    float3 displacement = float3(components) * displacementScale;
    return particlePosition(positions, particleIndex)
        - displacement * (1.0f - interpolation);
}

static uint particleID(
    const device uint4 *ids,
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

static uint pointLODHash(uint value) {
    uint hash = value;
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

static bool particleVisible(float3 position, float4x4 viewProjection,
                            float2 cullingBounds, uint hasCullingBounds,
                            float billboardRadius, uint cullingMode,
                            uint2 viewport, constant FrustumPlanes &frustum) {
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
    return insideBounds && insideFrustum;
}

struct DirectVisibility {
    float4x4 viewProjection;
    FrustumPlanes frustum;
    float4 bounds;
    uint4 modes;
};

static bool directVisible(float3 position, constant DirectVisibility &visibility) {
    return particleVisible(position, visibility.viewProjection, visibility.bounds.xy,
                           visibility.modes.y, visibility.bounds.z, visibility.modes.x,
                           visibility.modes.zw, visibility.frustum);
}

kernel void countDirectVisibility(
    const device uint *displacements [[buffer(0)]],
    const device PositionBatch *positions [[buffer(1)]],
    device uint *counts [[buffer(2)]],
    constant DirectVisibility &visibility [[buffer(3)]],
    constant float &interpolation [[buffer(4)]],
    constant float &displacementScale [[buffer(5)]],
    constant uint &count [[buffer(6)]],
    uint index [[thread_position_in_grid]],
    uint lane [[thread_index_in_threadgroup]],
    uint block [[threadgroup_position_in_grid]]
) {
    threadgroup uint sums[256];
    sums[lane] = index < count && directVisible(
        interpolatedPosition(positions, displacements, displacementScale, index, interpolation), visibility);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint stride = 128; stride > 0; stride >>= 1) {
        if (lane < stride) sums[lane] += sums[lane + stride];
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (lane == 0) counts[block] = sums[0];
}

kernel void classifyAndScanVisibility(
    const device uint *displacements [[buffer(0)]],
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
    constant float &displacementScale [[buffer(13)]],
    uint index [[thread_position_in_grid]],
    uint lane [[thread_index_in_threadgroup]],
    uint block [[threadgroup_position_in_grid]],
    uint blockSize [[threads_per_threadgroup]]
) {
    threadgroup uint scan[256];
    uint visible = 0;

    if (index < particleCount) {
        float3 position = interpolatedPosition(currentPositions, displacements, displacementScale, index, interpolation);
        visible = particleVisible(position, viewProjection, cullingBounds,
                                  hasCullingBounds, billboardRadius, cullingMode,
                                  viewport, frustum);
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
    const device uint *displacements [[buffer(0)]],
    const device uint *visibleIndices [[buffer(1)]],
    const device DrawArguments &visibleArguments [[buffer(2)]],
    device atomic_uint *tileCounts [[buffer(3)]],
    device uint *tileIndices [[buffer(4)]],
    constant float4x4 &viewProjection [[buffer(5)]],
    constant float &interpolation [[buffer(6)]],
    constant PointLODConfiguration &configuration [[buffer(7)]],
    const device PositionBatch *currentPositions [[buffer(8)]],
    constant float &displacementScale [[buffer(9)]],
    uint index [[thread_position_in_grid]]
) {
    if (index >= visibleArguments.vertexCount) return;
    uint particleIndex = visibleIndices[index];
    float3 position = interpolatedPosition(currentPositions, displacements, displacementScale, particleIndex, interpolation);
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
    const device uint4 *ids [[buffer(0)]],
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
    const device uint *displacements [[buffer(0)]],
    const device uint *visibleIndices [[buffer(1)]],
    constant float4x4 &viewProjection [[buffer(2)]],
    constant float &interpolation [[buffer(3)]],
    const device ushort *colorIndices [[buffer(6)]],
    const device PositionBatch *currentPositions [[buffer(7)]],
    constant float &displacementScale [[buffer(8)]],
    const device float4 *colorPalette [[buffer(9)]]
) {
    uint particleIndex = visibleIndices[vertexID];
    PointVertex output;
    float3 position = interpolatedPosition(currentPositions, displacements, displacementScale, particleIndex, interpolation);
    output.position = viewProjection * float4(position, 1);
    output.pointSize = 1;
    output.color = half4(particleColor(colorIndices, colorPalette, particleIndex));
    return output;
}

vertex PointVertex pointDirectVertex(
    uint vertexID [[vertex_id]],
    const device uint *displacements [[buffer(0)]],
    constant float4x4 &viewProjection [[buffer(2)]],
    constant float &interpolation [[buffer(3)]],
    const device ushort *colorIndices [[buffer(6)]],
    const device PositionBatch *currentPositions [[buffer(7)]],
    constant float &displacementScale [[buffer(8)]],
    const device float4 *colorPalette [[buffer(9)]],
    constant DirectVisibility &visibility [[buffer(10)]]
) {
    uint particleIndex = vertexID;
    PointVertex output;
    float3 position = interpolatedPosition(currentPositions, displacements, displacementScale, particleIndex, interpolation);
    output.position = directVisible(position, visibility)
        ? viewProjection * float4(position, 1) : float4(2, 2, 2, 1);
    output.pointSize = 1;
    output.color = half4(particleColor(colorIndices, colorPalette, particleIndex));
    return output;
}

vertex PointVertex pointLODVertex(
    uint vertexID [[vertex_id]],
    const device uint *displacements [[buffer(0)]],
    const device uint *visibleIndices [[buffer(1)]],
    constant float4x4 &viewProjection [[buffer(2)]],
    constant float &interpolation [[buffer(3)]],
    const device uint *lodVisibleIndices [[buffer(4)]],
    const device PointLODState &state [[buffer(5)]],
    const device ushort *colorIndices [[buffer(6)]],
    const device PositionBatch *currentPositions [[buffer(7)]],
    constant float &displacementScale [[buffer(8)]],
    const device float4 *colorPalette [[buffer(9)]]
) {
    uint particleIndex = state.active
        ? lodVisibleIndices[vertexID]
        : visibleIndices[vertexID];
    PointVertex output;
    float3 position = interpolatedPosition(currentPositions, displacements, displacementScale, particleIndex, interpolation);
    output.position = viewProjection * float4(position, 1);
    output.pointSize = 1;
    output.color = half4(particleColor(colorIndices, colorPalette, particleIndex));
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
    const device uint *displacements [[buffer(0)]],
    const device uint *visibleIndices [[buffer(1)]],
    constant CameraFrame &camera [[buffer(2)]],
    constant float &interpolation [[buffer(3)]],
    constant BillboardConfiguration &configuration [[buffer(4)]],
    const device ushort *colorIndices [[buffer(6)]],
    const device PositionBatch *currentPositions [[buffer(7)]],
    constant float &displacementScale [[buffer(8)]],
    const device float4 *colorPalette [[buffer(9)]]
) {
    uint particleIndex = visibleIndices[instanceID];
    float3 center = interpolatedPosition(currentPositions, displacements, displacementScale, particleIndex, interpolation);
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
    output.color = half4(particleColor(colorIndices, colorPalette, particleIndex));
    return output;
}

vertex BillboardVertex billboardDirectVertex(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    const device uint *displacements [[buffer(0)]],
    constant CameraFrame &camera [[buffer(2)]],
    constant float &interpolation [[buffer(3)]],
    constant BillboardConfiguration &configuration [[buffer(4)]],
    const device ushort *colorIndices [[buffer(6)]],
    const device PositionBatch *currentPositions [[buffer(7)]],
    constant float &displacementScale [[buffer(8)]],
    const device float4 *colorPalette [[buffer(9)]],
    constant DirectVisibility &visibility [[buffer(10)]]
) {
    uint particleIndex = instanceID;
    float3 center = interpolatedPosition(currentPositions, displacements, displacementScale, particleIndex, interpolation);
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
    if (!directVisible(center, visibility)) output.position = float4(2, 2, 2, 1);
    output.color = half4(particleColor(colorIndices, colorPalette, particleIndex));
    return output;
}

fragment half4 pointFragment(PointVertex input [[stage_in]]) {
    return input.color;
}

fragment half4 billboardFragment(BillboardVertex input [[stage_in]]) {
    return input.color;
}

// Shared point/quad coverage. Shape only changes the projected footprint;
// colour/depth ownership and translucent ordering are shared.
struct RasterConfiguration { float4 values; uint4 modes; };
struct ParticleFootprint {
    float4 center; float4 right; float4 up; uint4 bounds;
    float3 u; float3 v; float3 q; float3 depth;
};
static float3 screenPlane(float3 row, float2 inverseViewport) {
    return float3(row.xy * inverseViewport * float2(2, -2), row.z - row.x + row.y);
}

template <bool VertexOnly = false>
static ParticleFootprint projectParticle(float3 position, constant CameraFrame &camera,
                                        constant RasterConfiguration &configuration, float2 corner = float2(0)) {
    ParticleFootprint result;
    result.center = camera.viewProjection * float4(position, 1);
    result.right = 0;
    result.up = 0;
    result.bounds = 0;
    uint2 viewport = uint2(camera.viewport.xy);
    if (!all(isfinite(result.center))) return result;
    if (configuration.modes.z == 0) {
        if (VertexOnly) return result;
        if (result.center.w <= 0 || result.center.z < 0 || result.center.z >= result.center.w) return result;
        float2 screen = fma(result.center.xy / result.center.w,
            float2(viewport) * float2(0.5f, -0.5f), float2(viewport) * 0.5f - 1.0f / 512.0f);
        if (any(screen < 0) || any(screen >= float2(viewport))) return result;
        uint2 pixel = uint2(floor(screen));
        result.bounds = uint4(pixel, pixel + 1);
        return result;
    }
    if (any(configuration.values.xy <= 0)) return result;
    float sine = sin(configuration.values.z), cosine = cos(configuration.values.z);
    float2 localRight = configuration.values.x * float2(cosine, sine);
    float2 localUp = configuration.values.y * float2(-sine, cosine);
    if (configuration.modes.x == 1) {
        if (VertexOnly) {
            float2 local = corner * configuration.values.xy;
            local = float2(local.x * cosine - local.y * sine, local.x * sine + local.y * cosine);
            result.center.xy += local * float2(camera.viewport.z * 2, camera.viewport.w * 2) * result.center.w;
            return result;
        }
        result.right = float4(localRight * camera.viewport.zw * 2 * result.center.w, 0, 0);
        result.up = float4(localUp * camera.viewport.zw * 2 * result.center.w, 0, 0);
    } else {
        float3 right, up;
        billboardBasis(position, camera, configuration.modes.y, right, up);
        if (VertexOnly) {
            float2 local = corner * configuration.values.xy;
            local = float2(local.x * cosine - local.y * sine, local.x * sine + local.y * cosine);
            result.center = camera.viewProjection * float4(position + right * local.x + up * local.y, 1);
            return result;
        }
        result.right = camera.viewProjection * float4(right * localRight.x + up * localRight.y, 0);
        result.up = camera.viewProjection * float4(right * localUp.x + up * localUp.y, 0);
    }
    float3 a = float3(result.right.xy, result.right.w);
    float3 b = float3(result.up.xy, result.up.w);
    float3 c = float3(result.center.xy, result.center.w);
    float determinant = dot(a, cross(b, c));
    if (abs(determinant) < 1e-20f) return result;
    float3 u = cross(b, c) / determinant;
    float3 v = cross(c, a) / determinant;
    float3 q = cross(a, b) / determinant;
    result.u = screenPlane(u, camera.viewport.zw);
    result.v = screenPlane(v, camera.viewport.zw);
    result.q = screenPlane(q, camera.viewport.zw);
    result.depth = screenPlane(result.right.z * u + result.up.z * v + result.center.z * q, camera.viewport.zw);
    float2 minimum = float2(INFINITY), maximum = float2(-INFINITY);
    bool crossesEye = false;
    for (uint corner = 0; corner < 4; ++corner) {
        float4 clip = result.center + result.right * ((corner & 1) ? 0.5f : -0.5f)
                                   + result.up * ((corner & 2) ? 0.5f : -0.5f);
        if (clip.w <= 0) { crossesEye = true; continue; }
        float2 screen = fma(clip.xy / clip.w, float2(viewport) * float2(0.5f, -0.5f), float2(viewport) * 0.5f);
        minimum = min(minimum, screen);
        maximum = max(maximum, screen);
    }
    // Near/eye-plane crossings are evaluated homogeneously during coverage.
    // A full viewport bound is conservative and cannot drop a clipped corner.
    if (crossesEye) { result.bounds = uint4(0, 0, viewport); return result; }
    minimum = clamp(floor(minimum), float2(0), float2(viewport));
    maximum = clamp(ceil(maximum), float2(0), float2(viewport));
    result.bounds = uint4(uint2(minimum), uint2(maximum));
    return result;
}

static bool insideParticleEdge(float value, float3 equation) {
    // For an inward edge normal in screen coordinates, equality belongs to
    // top/left edges only. This prevents a pixel-centre edge from being doubled.
    return value > 0 || (value == 0 && (equation.x > 0 || (equation.x == 0 && equation.y > 0)));
}

static float particleCoverage(ParticleFootprint footprint, uint2 pixel,
                              constant CameraFrame &camera, constant RasterConfiguration &configuration) {
    if (any(pixel < footprint.bounds.xy) || any(pixel >= footprint.bounds.zw)) return -1;
    if (configuration.modes.z == 0) return max(footprint.center.z / footprint.center.w, 0.0f);
    float3 sample = float3(float2(pixel) + 0.5f, 1);
    float u = dot(footprint.u, sample), v = dot(footprint.v, sample), q = dot(footprint.q, sample);
    if (q <= 0
        || !insideParticleEdge(0.5f * q + u, 0.5f * footprint.q + footprint.u)
        || !insideParticleEdge(0.5f * q - u, 0.5f * footprint.q - footprint.u)
        || !insideParticleEdge(0.5f * q + v, 0.5f * footprint.q + footprint.v)
        || !insideParticleEdge(0.5f * q - v, 0.5f * footprint.q - footprint.v)) return -1;
    float depth = dot(footprint.depth, sample);
    return depth >= 0 && depth < 1 ? max(depth, 0.0f) : -1;
}

kernel void clearParticleRaster(device ulong *winners [[buffer(0)]],
    constant uint &count [[buffer(1)]], device uint4 *arguments [[buffer(2)]],
    constant uint &vertices [[buffer(3)]], uint index [[thread_position_in_grid]]) {
    if (index == 0) *arguments = uint4(vertices, 0, 0, 0);
    if (index < count) winners[index] = ULONG_MAX;
}

// Match ParticleRasterPass's dispatch limit so compilation targets the actual
// threadgroup size instead of reserving for larger groups.
[[max_total_threads_per_threadgroup(128)]]
kernel void rasterParticles(
    const device uint *displacements [[buffer(0)]], const device PositionBatch *positions [[buffer(1)]],
    device atomic_ulong *winners [[buffer(2)]], constant DirectVisibility &visibility [[buffer(3)]],
    constant float &interpolation [[buffer(4)]], constant float &scale [[buffer(5)]],
    constant uint &count [[buffer(6)]], constant CameraFrame &camera [[buffer(7)]],
    constant RasterConfiguration &configuration [[buffer(8)]], device atomic_uint *arguments [[buffer(9)]],
    uint index [[thread_position_in_grid]]) {
    if (index >= count || atomic_load_explicit(arguments + 1, memory_order_relaxed) != 0) return;
    float3 position = interpolatedPosition(positions, displacements, scale, index, interpolation);
    if (!directVisible(position, visibility)) return;
    ParticleFootprint footprint = projectParticle(position, camera, configuration);
    if (any(footprint.bounds.xy >= footprint.bounds.zw)) return;
    uint2 extent = footprint.bounds.zw - footprint.bounds.xy;
    if (extent.x * extent.y > configuration.modes.w) {
        // Bound compute work for large/near-plane footprints. A GPU-only flag
        // selects the same ordered geometry compositor for the complete draw.
        atomic_store_explicit(arguments + 1, configuration.modes.z == 0 ? 1u : count, memory_order_relaxed);
        return;
    }
    for (uint y = footprint.bounds.y; y < footprint.bounds.w; ++y) {
        for (uint x = footprint.bounds.x; x < footprint.bounds.z; ++x) {
            float depth = particleCoverage(footprint, uint2(x, y), camera, configuration);
            if (depth < 0) continue;
            uint address = y * uint(camera.viewport.x) + x;
            uint bits = as_type<uint>(depth);
            ulong key = (ulong(bits) << 32) | ulong(index);
            atomic_min_explicit(winners + address, key, memory_order_relaxed);
        }
    }
}

struct ParticleRasterVertex { float4 position [[position]]; };
struct ParticleRasterOutput { half4 color [[color(0)]]; float depth [[depth(any)]]; };
vertex ParticleRasterVertex particleRasterVertex(uint index [[vertex_id]]) {
    return { float4(index == 2 ? 3 : -1, index == 1 ? 3 : -1, 0, 1) };
}

fragment ParticleRasterOutput particleRasterFragment(
    ParticleRasterVertex input [[stage_in]], const device ulong *winners [[buffer(0)]],
    const device ushort *indices [[buffer(1)]], const device float4 *palette [[buffer(2)]],
    constant uint &width [[buffer(3)]], const device uint4 &arguments [[buffer(4)]]) {
    if (arguments.y != 0) discard_fragment();
    uint2 pixel = uint2(input.position.xy);
    ulong key = winners[pixel.y * width + pixel.x];
    if (key == ULONG_MAX) discard_fragment();
    return { half4(palette[indices[uint(key)]]), as_type<float>(uint(key >> 32)) };
}

// One ordered shader serves both primitive shapes. Its vertex specialization
// skips pixel coverage construction, which the hardware rasterizer owns.
vertex PointVertex particleGeometryVertex(
    uint vertexID [[vertex_id]], uint instanceID [[instance_id]],
    const device uint *displacements [[buffer(0)]], const device PositionBatch *positions [[buffer(1)]],
    constant CameraFrame &camera [[buffer(2)]], constant float &interpolation [[buffer(3)]],
    constant RasterConfiguration &configuration [[buffer(4)]], constant float &scale [[buffer(5)]],
    const device ushort *indices [[buffer(7)]], const device float4 *palette [[buffer(8)]],
    constant DirectVisibility &visibility [[buffer(9)]]) {
    uint index = configuration.modes.z == 0 ? vertexID : instanceID;
    float3 position = interpolatedPosition(positions, displacements, scale, index, interpolation);
    float2 corner = float2((vertexID & 1) ? 0.5f : -0.5f, (vertexID & 2) ? 0.5f : -0.5f);
    ParticleFootprint footprint = projectParticle<true>(position, camera, configuration, corner);
    PointVertex result;
    result.position = directVisible(position, visibility) ? footprint.center : float4(2, 2, 2, 1);
    result.pointSize = 1;
    result.color = half4(palette[indices[index]]);
    return result;
}
