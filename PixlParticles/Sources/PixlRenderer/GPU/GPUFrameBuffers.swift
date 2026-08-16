import Swift

@MainActor
final class GPUFrameBuffers {
    private let platform: any Platform
    private let frameCount: Int
    private var positions: [any Buffer] = []
    private var culling: [GPUCullingBuffers] = []
    private var ids: [any Buffer] = []
    private var lod: [GPULODBuffers] = []
    private var initializedIDs: [Bool] = []
    private var capacity = 0
    private var lodCapacity = 0
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
    ) throws -> GPUFrameResources {
        try ensureCapacity(max(count, 1))
        let usesLOD = settings.isEnabled
            && count > 0
            && count >= settings.activationCount
        if usesLOD {
            try ensureLODCapacity(
                particleCount: max(count, 1),
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
            initializedIDs = .init(repeating: false, count: initializedIDs.count)
        }
        if usesLOD && !initializedIDs[frameIndex] {
            ids[frameIndex].withMutableBytes { bytes in
                let destination = bytes.bindMemory(to: UInt64.self)
                writeIDs(.init(rebasing: destination[..<count]))
            }
            initializedIDs[frameIndex] = true
        }

        let resources = GPUFrameResources(
            positions: positions[positionIndex],
            culling: culling[frameIndex],
            ids: usesLOD ? ids[frameIndex] : nil,
            lod: usesLOD ? lod[frameIndex] : nil
        )
        frameIndex = (frameIndex + 1) % frameCount
        return resources
    }

    private func ensureCapacity(_ required: Int) throws {
        guard required > capacity else { return }

        let blockCapacity = (required + GPUCullingPass.threadCount - 1)
            / GPUCullingPass.threadCount
        var positions: [any Buffer] = []
        var culling: [GPUCullingBuffers] = []
        positions.reserveCapacity(frameCount)
        culling.reserveCapacity(frameCount)

        for _ in 0..<frameCount {
            guard let positionBuffer = platform.makeBuffer(
                length: required * MemoryLayout<PositionPair>.stride,
                memory: .cpuVisible
            ), let cullingBuffers = GPUCullingBuffers(
                platform: platform,
                particleCapacity: required,
                blockCapacity: blockCapacity
            ) else {
                throw GPUError.buffer
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
        tileCount: Int
    ) throws {
        guard particleCount > lodCapacity || tileCount > tileCapacity else {
            return
        }
        let particleCapacity = max(particleCount, lodCapacity)
        let tileCapacity = max(tileCount, self.tileCapacity)
        var ids: [any Buffer] = []
        var lod: [GPULODBuffers] = []
        ids.reserveCapacity(frameCount)
        lod.reserveCapacity(frameCount)

        for _ in 0..<frameCount {
            guard let idBuffer = platform.makeBuffer(
                length: particleCapacity * MemoryLayout<UInt64>.stride,
                memory: .cpuVisible
            ), let lodBuffers = GPULODBuffers(
                platform: platform,
                particleCapacity: particleCapacity,
                tileCapacity: max(tileCapacity, 1)
            ) else { throw GPUError.buffer }
            ids.append(idBuffer)
            lod.append(lodBuffers)
        }
        self.ids = ids
        self.lod = lod
        initializedIDs = .init(repeating: false, count: frameCount)
        lodCapacity = particleCapacity
        self.tileCapacity = tileCapacity
    }

    private func releaseLOD() {
        ids = []
        lod = []
        initializedIDs = []
        lodCapacity = 0
        tileCapacity = 0
    }

    private func tileCount(viewport: ViewportSize, tileSize: Int) -> Int {
        let size = UInt32(tileSize)
        let columns = (viewport.width + size - 1) / size
        let rows = (viewport.height + size - 1) / size
        return Int(columns * rows)
    }
}

struct GPUFrameResources {
    let positions: any Buffer
    let culling: GPUCullingBuffers
    let ids: (any Buffer)?
    let lod: GPULODBuffers?
}
