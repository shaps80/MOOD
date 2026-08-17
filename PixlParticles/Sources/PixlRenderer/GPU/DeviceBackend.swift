import Swift

public final class DeviceBackend: Backend {
    private static let frameCount = 2

    private let platform: any Platform
    private let buffers: FrameBuffers
    private let culling: CullingPass
    private let lod: LODPass
    private let editor: EditorPass
    private let points: PointPass
    public var pointLOD: PointLOD
    public var groundPlane = GroundPlane()
    public var cullingBounds = CullingBounds()
    public var cameraFrustum = CameraFrustum()

    public init(
        platform: any Platform,
        pointLOD: PointLOD = .init()
    ) throws {
        self.platform = platform
        self.pointLOD = pointLOD
        buffers = FrameBuffers(
            platform: platform,
            frameCount: Self.frameCount
        )
        culling = try CullingPass(platform: platform)
        lod = try LODPass(platform: platform)
        editor = try EditorPass(platform: platform)
        points = try PointPass(platform: platform)
    }

    public func renderPoints(
        count: Int,
        positionsChanged: Bool,
        idsChanged: Bool,
        interpolation: Float,
        cullingViewProjection: Matrix4x4,
        viewProjection: Matrix4x4,
        viewport: ViewportSize,
        writePositions: (UnsafeMutableBufferPointer<PositionPair>) -> Void,
        writeIDs: (UnsafeMutableBufferPointer<UInt64>) -> Void
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
            idsChanged: idsChanged,
            lod: pointLOD,
            viewport: viewport,
            writePositions: writePositions,
            writeIDs: writeIDs
        )
        guard let commandBuffer = platform.makeCommandBuffer() else {
            throw RenderError.commandBuffer
        }
        commandBuffer.label = "Pixl Particles Frame"
        try culling.encode(
            count: count,
            interpolation: interpolation,
            viewProjection: cullingViewProjection,
            cullingBounds: cullingBounds,
            positions: resources.positions,
            buffers: resources.culling,
            into: commandBuffer
        )

        if let ids = resources.ids, let lodBuffers = resources.lod {
            try lod.encode(
                settings: pointLOD,
                viewport: viewport,
                interpolation: interpolation,
                viewProjection: cullingViewProjection,
                positions: resources.positions,
                ids: ids,
                culling: resources.culling,
                lod: lodBuffers,
                into: commandBuffer
            )
        }

        guard let target = platform.currentRenderTarget() else { return }
        guard let encoder = commandBuffer.makeRenderEncoder(target: target) else {
            throw RenderError.encoder
        }
        encoder.label = "Scene Draw"
        editor.encode(
            groundPlane: groundPlane,
            cullingBounds: cullingBounds,
            cameraFrustum: cameraFrustum,
            viewProjection: viewProjection,
            into: encoder
        )
        points.encode(
            positions: resources.positions,
            visibleIndices: resources.culling.visibleIndices,
            indirectArguments: resources.culling.indirectArguments,
            lod: resources.lod,
            interpolation: interpolation,
            viewProjection: viewProjection,
            into: encoder
        )
        encoder.endEncoding()

        commandBuffer.present(target)
        submitted = true
        platform.submit(commandBuffer)
    }
}

enum RenderError: Error {
    case buffer
    case commandBuffer
    case encoder
    case pipeline
}
