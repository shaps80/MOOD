import Swift

final class FrameBuffers {
    private let platform: any Platform
    private let frameCount: Int
    private var culling: [CullingBuffers] = []
    private var lod: [LODBuffers] = []
    private var counts: [VisibilityCounts] = []
    private var countCapacity = 0
    private var shared: SharedParticleBuffers?
    private var capacity = 0
    private var lodCapacity = 0
    private var lodVisibleCapacity = 0
    private var tileCapacity = 0
    private var frameIndex = 0

    init(platform: any Platform, frameCount: Int) {
        self.platform = platform
        self.frameCount = frameCount
    }

    func prepare(
        count: Int,
        buffers: ParticleBuffers,
        lod settings: PointLOD?,
        viewport: ViewportSize,
        capturesDiagnostics: Bool = false
    ) throws -> FrameResources {
        try ensureSharedBuffers(buffers)

        let usesLOD = settings.map {
            $0.isEnabled && count > 0 && count >= $0.activationCount
        } ?? false
        if usesLOD, let settings {
            try ensureCapacity(max(buffers.capacity, 1))
            counts = []
            countCapacity = 0
            try ensureLODCapacity(
                particleCount: max(buffers.capacity, 1),
                visibleCount: settings.maximumVisibleCount,
                tileCount: tileCount(viewport: viewport, tileSize: settings.tileSize)
            )
        } else {
            releaseLOD()
            culling = []
            capacity = 0
            if capturesDiagnostics {
                try ensureCountCapacity(max(buffers.capacity, 1))
            } else {
                counts = []
                countCapacity = 0
            }
        }

        guard let shared else { throw RenderError.buffer }
        let resources = FrameResources(
            displacements: shared.displacements,
            currentPositions: shared.currentPositions,
            colorIndices: shared.colorIndices,
            colorPalette: shared.colorPalette,
            culling: usesLOD ? culling[frameIndex] : nil,
            counts: counts.isEmpty ? nil : counts[frameIndex],
            ids: usesLOD ? shared.ids : nil,
            lod: usesLOD ? lod[frameIndex] : nil
        )
        return resources
    }

    /// Advance only for submitted work, so dropped drawables cannot desynchronize
    /// the CPU readback slot from the platform's in-flight frame limit.
    func didSubmit() {
        frameIndex = (frameIndex + 1) % frameCount
    }

    private func ensureCountCapacity(_ required: Int) throws {
        guard required > countCapacity || required <= countCapacity / 4 else { return }
        var replacement: [VisibilityCounts] = []
        for _ in 0..<frameCount {
            guard let counts = VisibilityCounts(platform: platform, capacity: required)
            else { throw RenderError.buffer }
            replacement.append(counts)
        }
        counts = replacement
        countCapacity = required
    }

    private func ensureSharedBuffers(_ source: ParticleBuffers) throws {
        if let shared, shared.matches(source) { return }

        guard let displacements = platform.makeBuffer(
            sharing: source.displacements
        ), let currentPositions = platform.makeBuffer(
            sharing: source.currentPositions
        ), let colorIndices = platform.makeBuffer(
            sharing: source.colorIndices
        ), let colorPalette = platform.makeBuffer(sharing: source.colorPalette),
        let ids = platform.makeBuffer(sharing: source.ids)
        else { throw RenderError.buffer }

        shared = SharedParticleBuffers(
            source: source,
            displacements: displacements,
            currentPositions: currentPositions,
            colorIndices: colorIndices,
            colorPalette: colorPalette,
            ids: ids
        )
    }

    private func ensureCapacity(_ required: Int) throws {
        let needsGrowth = required > capacity
        let canReleaseExcess = required <= capacity / 4
        guard needsGrowth || canReleaseExcess else { return }

        let blockCapacity = (required + CullingPass.threadCount - 1)
            / CullingPass.threadCount
        var culling: [CullingBuffers] = []
        culling.reserveCapacity(frameCount)

        for _ in 0..<frameCount {
            guard let buffers = CullingBuffers(
                platform: platform,
                particleCapacity: required,
                blockCapacity: blockCapacity
            ) else { throw RenderError.buffer }
            culling.append(buffers)
        }

        self.culling = culling
        capacity = required
        frameIndex = 0
        releaseLOD()
    }

    private func ensureLODCapacity(
        particleCount: Int,
        visibleCount: Int,
        tileCount: Int
    ) throws {
        guard particleCount > lodCapacity
                || visibleCount > lodVisibleCapacity
                || tileCount > tileCapacity
        else { return }

        let particleCapacity = max(particleCount, lodCapacity)
        let visibleCapacity = max(visibleCount, lodVisibleCapacity)
        let tileCapacity = max(tileCount, self.tileCapacity)
        var lod: [LODBuffers] = []
        lod.reserveCapacity(frameCount)

        for _ in 0..<frameCount {
            guard let buffers = LODBuffers(
                platform: platform,
                visibleCapacity: visibleCapacity,
                tileCapacity: max(tileCapacity, 1)
            ) else { throw RenderError.buffer }
            lod.append(buffers)
        }
        self.lod = lod
        lodCapacity = particleCapacity
        lodVisibleCapacity = visibleCapacity
        self.tileCapacity = tileCapacity
    }

    private func releaseLOD() {
        lod = []
        lodCapacity = 0
        lodVisibleCapacity = 0
        tileCapacity = 0
    }

    private func tileCount(viewport: ViewportSize, tileSize: Int) -> Int {
        let size = UInt32(tileSize)
        let columns = (viewport.width + size - 1) / size
        let rows = (viewport.height + size - 1) / size
        return Int(columns * rows)
    }
}

private struct SharedParticleBuffers {
    let source: ParticleBuffers
    let displacements: any Buffer
    let currentPositions: any Buffer
    let colorIndices: any Buffer
    let colorPalette: any Buffer
    let ids: any Buffer

    func matches(_ other: ParticleBuffers) -> Bool {
        source.displacements === other.displacements
            && source.currentPositions === other.currentPositions
            && source.colorIndices === other.colorIndices
            && source.colorPalette === other.colorPalette
            && source.ids === other.ids
    }

}

struct FrameResources {
    let displacements: any Buffer
    let currentPositions: any Buffer
    let colorIndices: any Buffer
    let colorPalette: any Buffer
    let culling: CullingBuffers?
    let counts: VisibilityCounts?
    let ids: (any Buffer)?
    let lod: LODBuffers?
}
