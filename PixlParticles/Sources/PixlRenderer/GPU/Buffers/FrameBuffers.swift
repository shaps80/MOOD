import Swift

final class FrameBuffers {
    private let platform: any Platform
    private let frameCount: Int
    private var culling: [CullingBuffers] = []
    private var lod: [LODBuffers] = []
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
        viewport: ViewportSize
    ) throws -> FrameResources {
        try ensureCapacity(max(count, 1))
        try ensureSharedBuffers(buffers)

        let usesLOD = settings.map {
            $0.isEnabled && count > 0 && count >= $0.activationCount
        } ?? false
        if usesLOD, let settings {
            try ensureLODCapacity(
                particleCount: max(count, 1),
                visibleCount: settings.maximumVisibleCount,
                tileCount: tileCount(viewport: viewport, tileSize: settings.tileSize)
            )
        } else {
            releaseLOD()
        }

        guard let shared else { throw RenderError.buffer }
        let resources = FrameResources(
            previousPositions: shared.previousPositions(for: buffers),
            currentPositions: shared.currentPositions(for: buffers),
            colors: shared.colors,
            culling: culling[frameIndex],
            ids: usesLOD ? shared.ids : nil,
            lod: usesLOD ? lod[frameIndex] : nil
        )
        frameIndex = (frameIndex + 1) % frameCount
        return resources
    }

    private func ensureSharedBuffers(_ source: ParticleBuffers) throws {
        if let shared, shared.matches(source) { return }

        guard let previousPositions = platform.makeBuffer(
            sharing: source.previousPositions
        ), let currentPositions = platform.makeBuffer(
            sharing: source.currentPositions
        ), let colors = platform.makeBuffer(
            sharing: source.colors
        ), let ids = platform.makeBuffer(sharing: source.ids)
        else { throw RenderError.buffer }

        shared = SharedParticleBuffers(
            source: source,
            previousPositions: previousPositions,
            currentPositions: currentPositions,
            colors: colors,
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
    let previousPositions: any Buffer
    let currentPositions: any Buffer
    let colors: any Buffer
    let ids: any Buffer

    func matches(_ other: ParticleBuffers) -> Bool {
        let positionsMatch = (
            source.previousPositions === other.previousPositions
                && source.currentPositions === other.currentPositions
        ) || (
            source.previousPositions === other.currentPositions
                && source.currentPositions === other.previousPositions
        )
        return positionsMatch
            && source.colors === other.colors
            && source.ids === other.ids
    }

    func previousPositions(for other: ParticleBuffers) -> any Buffer {
        source.previousPositions === other.previousPositions
            ? previousPositions
            : currentPositions
    }

    func currentPositions(for other: ParticleBuffers) -> any Buffer {
        source.currentPositions === other.currentPositions
            ? currentPositions
            : previousPositions
    }
}

struct FrameResources {
    let previousPositions: any Buffer
    let currentPositions: any Buffer
    let colors: any Buffer
    let culling: CullingBuffers
    let ids: (any Buffer)?
    let lod: LODBuffers?
}
