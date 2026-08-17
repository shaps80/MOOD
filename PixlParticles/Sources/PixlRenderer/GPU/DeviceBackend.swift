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
    public var capturesDiagnostics = false
    public private(set) var visibleCount: Int?
    public private(set) var cpuRenderTime: Double?
    public var onGPUTime: (@Sendable (Double?) -> Void)?
    public var onPresented: (@Sendable (Double) -> Void)?

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
        let renderStart = capturesDiagnostics ? ContinuousClock.now : nil
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
        visibleCount = capturesDiagnostics
            ? resources.culling.capturedVisibleCount
            : nil
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

        if capturesDiagnostics {
            try culling.encodeVisibleCountCapture(
                arguments: resources.lod?.drawArguments
                    ?? resources.culling.indirectArguments,
                destination: resources.culling.diagnosticCount,
                into: commandBuffer
            )
            if let onGPUTime { commandBuffer.addCompletedHandler(onGPUTime) }
        }

        let drawableWaitStart = capturesDiagnostics ? ContinuousClock.now : nil
        guard let target = platform.currentRenderTarget() else { return }
        let drawableWaitEnd = capturesDiagnostics ? ContinuousClock.now : nil
        if capturesDiagnostics, let onPresented {
            target.addPresentedHandler(onPresented)
        }
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
        if let renderStart, let drawableWaitStart, let drawableWaitEnd {
            let beforeDrawable = Self.seconds(
                renderStart.duration(to: drawableWaitStart)
            )
            let afterDrawable = Self.seconds(
                drawableWaitEnd.duration(to: .now)
            )
            cpuRenderTime = beforeDrawable + afterDrawable
        } else {
            cpuRenderTime = nil
        }
    }

    private static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) / 1e18
    }
}

enum RenderError: Error {
    case buffer
    case commandBuffer
    case encoder
    case pipeline
}
