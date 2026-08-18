import Swift

final class DeviceRenderer {
    private static let frameCount = 2

    private let platform: any Platform
    private let buffers: FrameBuffers
    private let culling: CullingPass
    private let lod: LODPass
    private let points: PointPass
    private let billboards: BillboardPass

    var pointLOD: PointLOD
    var cullingBounds = CullingBounds()
    var capturesDiagnostics = false
    private(set) var visibleCount: Int?
    private(set) var cpuRenderTime: Double?
    var onGPUTime: (@Sendable (Double?) -> Void)?
    var onPresented: (@Sendable (Double) -> Void)?

    init(platform: any Platform, pointLOD: PointLOD) throws {
        self.platform = platform
        self.pointLOD = pointLOD
        buffers = FrameBuffers(platform: platform, frameCount: Self.frameCount)
        culling = try CullingPass(platform: platform)
        lod = try LODPass(platform: platform)
        points = try PointPass(platform: platform)
        billboards = try BillboardPass(platform: platform)
    }

    func renderParticles<Composition: RenderComposition>(
        count: Int,
        buffers particleBuffers: ParticleBuffers,
        renderer: ParticleRenderer,
        values: ParticleRenderValues,
        interpolation: Float,
        cullingViewProjection: Matrix4x4,
        camera: CameraFrame,
        composition: Composition
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
            buffers: particleBuffers,
            lod: renderer.mode == .point ? pointLOD : nil,
            viewport: camera.viewportSize
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
            renderer: renderer,
            values: values,
            viewport: camera.viewportSize,
            cullingBounds: cullingBounds,
            previousPositions: resources.previousPositions,
            currentPositions: resources.currentPositions,
            buffers: resources.culling,
            into: commandBuffer
        )

        if let ids = resources.ids, let lodBuffers = resources.lod {
            try lod.encode(
                settings: pointLOD,
                viewport: camera.viewportSize,
                interpolation: interpolation,
                viewProjection: cullingViewProjection,
                previousPositions: resources.previousPositions,
                currentPositions: resources.currentPositions,
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
                mode: renderer.mode,
                into: commandBuffer
            )
            if let onGPUTime { commandBuffer.addCompletedHandler(onGPUTime) }
        }

        try composition.prepare()
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
        composition.encodeBackground(into: encoder)
        switch renderer.mode {
        case .point:
            points.encode(
                previousPositions: resources.previousPositions,
                currentPositions: resources.currentPositions,
                colors: resources.colors,
                visibleIndices: resources.culling.visibleIndices,
                indirectArguments: resources.culling.indirectArguments,
                lod: resources.lod,
                interpolation: interpolation,
                viewProjection: camera.viewProjection,
                into: encoder
            )
        case .billboard:
            billboards.encode(
                previousPositions: resources.previousPositions,
                currentPositions: resources.currentPositions,
                colors: resources.colors,
                visibleIndices: resources.culling.visibleIndices,
                indirectArguments: resources.culling.indirectArguments,
                renderer: renderer.billboard,
                values: values,
                interpolation: interpolation,
                camera: camera,
                into: encoder
            )
        }
        composition.encodeOverlay(into: encoder)
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
