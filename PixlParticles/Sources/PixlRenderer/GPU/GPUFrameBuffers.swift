import Swift

@MainActor
final class GPUFrameBuffers {
    private let platform: any Platform
    private let frameCount: Int
    private var positions: [any Buffer] = []
    private var culling: [GPUCullingBuffers] = []
    private var capacity = 0
    private var positionIndex = -1
    private var frameIndex = 0

    init(platform: any Platform, frameCount: Int) {
        self.platform = platform
        self.frameCount = frameCount
    }

    func prepare(
        count: Int,
        positionsChanged: Bool,
        writePositions: (UnsafeMutableBufferPointer<PositionPair>) -> Void
    ) throws -> GPUFrameResources {
        try ensureCapacity(max(count, 1))

        if positionsChanged || positionIndex < 0 {
            positionIndex = (positionIndex + 1) % frameCount
            positions[positionIndex].withMutableBytes { bytes in
                let destination = bytes.bindMemory(to: PositionPair.self)
                writePositions(.init(rebasing: destination[..<count]))
            }
        }

        let resources = GPUFrameResources(
            positions: positions[positionIndex],
            culling: culling[frameIndex]
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
    }
}

struct GPUFrameResources {
    let positions: any Buffer
    let culling: GPUCullingBuffers
}
