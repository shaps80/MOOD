import Swift

@MainActor
public final class GPUBackend: Backend {
    private static let frameCount = 2

    private let platform: any Platform
    private let buffers: GPUFrameBuffers
    private let culling: GPUCullingPass
    private let points: GPUPointPass
    public init(platform: any Platform) throws {
        self.platform = platform
        buffers = GPUFrameBuffers(
            platform: platform,
            frameCount: Self.frameCount
        )
        culling = try GPUCullingPass(platform: platform)
        points = try GPUPointPass(platform: platform)
    }

    public func renderPoints(
        count: Int,
        positionsChanged: Bool,
        interpolation: Float,
        viewProjection: Matrix4x4,
        writePositions: (UnsafeMutableBufferPointer<PositionPair>) -> Void
    ) throws {
        precondition(interpolation >= 0 && interpolation <= 1)

        platform.acquireFrame()
        var submitted = false
        defer {
            if !submitted { platform.releaseFrame() }
        }

        let resources = try buffers.prepare(
            count: count,
            positionsChanged: positionsChanged,
            writePositions: writePositions
        )
        guard let commandBuffer = platform.makeCommandBuffer() else {
            throw GPUError.commandBuffer
        }
        commandBuffer.label = "Pixl Particles Frame"
        try culling.encode(
            count: count,
            interpolation: interpolation,
            viewProjection: viewProjection,
            positions: resources.positions,
            buffers: resources.culling,
            into: commandBuffer
        )

        guard let target = platform.currentRenderTarget() else { return }
        try points.encode(
            positions: resources.positions,
            visibleIndices: resources.culling.visibleIndices,
            indirectArguments: resources.culling.indirectArguments,
            interpolation: interpolation,
            viewProjection: viewProjection,
            target: target,
            into: commandBuffer
        )

        commandBuffer.present(target)
        submitted = true
        platform.submit(commandBuffer)
    }
}

enum GPUError: Error {
    case buffer
    case commandBuffer
    case encoder
    case pipeline
}
