import Swift

final class FrameBuffers {
    private let platform: any Platform
    private let frameCount: Int
    private var positions: [any Buffer] = []
    private var culling: [CullingBuffers] = []
    private var ids: (any Buffer)?
    private var lod: [LODBuffers] = []
    private var initializedIDs = false
    private var capacity = 0
    private var lodCapacity = 0
    private var lodVisibleCapacity = 0
    private var tileCapacity = 0
    private var positionIndex = -1
    private var frameIndex = 0

    init(platform: any Platform, frameCount: Int) {
        self.platform = platform
        self.frameCount = frameCount
    }

    func prepare(
        count: Int,
        positionsChanged: Bool,
        idsChanged: Bool,
        lod settings: PointLOD,
        viewport: ViewportSize,
        writePositions: (UnsafeMutableBufferPointer<PositionPair>) -> Void,
        writeIDs: (UnsafeMutableBufferPointer<UInt64>) -> Void
    ) throws -> FrameResources {
        try ensureCapacity(max(count, 1))
        let usesLOD = settings.isEnabled
            && count > 0
            && count >= settings.activationCount
        if usesLOD {
            try ensureLODCapacity(
                particleCount: max(count, 1),
                visibleCount: settings.maximumVisibleCount,
                tileCount: tileCount(viewport: viewport, tileSize: settings.tileSize)
            )
        } else {
            releaseLOD()
        }

        if positionsChanged || positionIndex < 0 {
            positionIndex = (positionIndex + 1) % frameCount
            positions[positionIndex].withMutableBytes { bytes in
                let destination = bytes.bindMemory(to: PositionPair.self)
                writePositions(.init(rebasing: destination[..<count]))
            }
        }

        if idsChanged {
            initializedIDs = false
        }
        if usesLOD && !initializedIDs, let ids {
            ids.withMutableBytes { bytes in
                let destination = bytes.bindMemory(to: UInt64.self)
                writeIDs(.init(rebasing: destination[..<count]))
            }
            initializedIDs = true
        }

        let resources = FrameResources(
            positions: positions[positionIndex],
            culling: culling[frameIndex],
            ids: usesLOD ? ids : nil,
            lod: usesLOD ? lod[frameIndex] : nil
        )
        frameIndex = (frameIndex + 1) % frameCount
        return resources
    }

    private func ensureCapacity(_ required: Int) throws {
        guard required > capacity else { return }

        let blockCapacity = (required + CullingPass.threadCount - 1)
            / CullingPass.threadCount
        var positions: [any Buffer] = []
        var culling: [CullingBuffers] = []
        positions.reserveCapacity(frameCount)
        culling.reserveCapacity(frameCount)

        for _ in 0..<frameCount {
            guard let positionBuffer = platform.makeBuffer(
                length: required * MemoryLayout<PositionPair>.stride,
                memory: .cpuVisible
            ), let cullingBuffers = CullingBuffers(
                platform: platform,
                particleCapacity: required,
                blockCapacity: blockCapacity
            ) else {
                throw RenderError.buffer
            }
            positions.append(positionBuffer)
            culling.append(cullingBuffers)
        }

        self.positions = positions
        self.culling = culling
        capacity = required
        positionIndex = -1
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
        else {
            return
        }
        let particleCapacity = max(particleCount, lodCapacity)
        let visibleCapacity = max(visibleCount, lodVisibleCapacity)
        let tileCapacity = max(tileCount, self.tileCapacity)
        var lod: [LODBuffers] = []
        lod.reserveCapacity(frameCount)

        guard let ids = platform.makeBuffer(
            length: particleCapacity * MemoryLayout<UInt64>.stride,
            memory: .cpuVisible
        ) else { throw RenderError.buffer }
        for _ in 0..<frameCount {
            guard let lodBuffers = LODBuffers(
                platform: platform,
                visibleCapacity: visibleCapacity,
                tileCapacity: max(tileCapacity, 1)
            ) else { throw RenderError.buffer }
            lod.append(lodBuffers)
        }
        self.ids = ids
        self.lod = lod
        initializedIDs = false
        lodCapacity = particleCapacity
        lodVisibleCapacity = visibleCapacity
        self.tileCapacity = tileCapacity
    }

    private func releaseLOD() {
        ids = nil
        lod = []
        initializedIDs = false
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

struct FrameResources {
    let positions: any Buffer
    let culling: CullingBuffers
    let ids: (any Buffer)?
    let lod: LODBuffers?
}
