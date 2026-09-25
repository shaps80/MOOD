import Swift

final class DeviceRenderer {
    private static let frameCount = 2

    private let platform: any Platform
    private let buffers: FrameBuffers
    private let visibilityCounts: VisibilityCountPass
    private let culling: CullingPass
    private let lod: LODPass
    private let points: PointPass
    private let billboards: BillboardPass

    var pointLOD: PointLOD
    var cullingBounds = CullingBounds()
    var capturesDiagnostics = false
    private(set) var visibleCount: Int?
    private(set) var cpuRenderTime: Double?
    var onGPUTimings: (@Sendable (GPUFrameTimings) -> Void)?
    var onGPUTime: (@Sendable (Double?) -> Void)?
    var onPresented: (@Sendable (Double) -> Void)?

    init(platform: any Platform, pointLOD: PointLOD) throws {
        self.platform = platform
        self.pointLOD = pointLOD
        buffers = FrameBuffers(platform: platform, frameCount: Self.frameCount)
        visibilityCounts = try VisibilityCountPass(platform: platform)
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
            viewport: camera.viewportSize,
            capturesDiagnostics: capturesDiagnostics
        )
        visibleCount = capturesDiagnostics
            ? (resources.culling?.capturedVisibleCount ?? resources.counts?.capturedCount)
            : nil
        guard let commandBuffer = platform.makeCommandBuffer() else {
            throw RenderError.commandBuffer
        }
        commandBuffer.label = "Pixl Particles Frame"
        if capturesDiagnostics, let onGPUTimings {
            commandBuffer.addTimingsHandler(onGPUTimings)
        }
        if let cullingBuffers = resources.culling {
            try culling.encode(
                count: count,
                interpolation: interpolation,
                viewProjection: cullingViewProjection,
                renderer: renderer,
                values: values,
                viewport: camera.viewportSize,
                cullingBounds: cullingBounds,
                displacements: resources.displacements,
                displacementScale: particleBuffers.displacementScale,
                currentPositions: resources.currentPositions,
                buffers: cullingBuffers,
                into: commandBuffer
            )

            if let ids = resources.ids, let lodBuffers = resources.lod {
                try lod.encode(
                    settings: pointLOD,
                    viewport: camera.viewportSize,
                    interpolation: interpolation,
                    viewProjection: cullingViewProjection,
                    displacements: resources.displacements,
                    displacementScale: particleBuffers.displacementScale,
                    currentPositions: resources.currentPositions,
                    ids: ids,
                    culling: cullingBuffers,
                    lod: lodBuffers,
                    into: commandBuffer
                )
            }

            if capturesDiagnostics {
                try culling.encodeVisibleCountCapture(
                    arguments: resources.lod?.drawArguments
                        ?? cullingBuffers.indirectArguments,
                    destination: cullingBuffers.diagnosticCount,
                    mode: renderer.mode,
                    into: commandBuffer
                )
            }
        }
        let visibility = DirectVisibility(
            viewProjection: cullingViewProjection, renderer: renderer,
            values: values, viewport: camera.viewportSize, cullingBounds: cullingBounds
        )
        if let counts = resources.counts {
            try visibilityCounts.encode(
                count: count, visibility: visibility, interpolation: interpolation,
                displacementScale: particleBuffers.displacementScale,
                displacements: resources.displacements, currentPositions: resources.currentPositions,
                counts: counts, into: commandBuffer
            )
        }
        if capturesDiagnostics, let onGPUTime { commandBuffer.addCompletedHandler(onGPUTime) }

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
                displacements: resources.displacements,
                displacementScale: particleBuffers.displacementScale,
                currentPositions: resources.currentPositions,
                colorIndices: resources.colorIndices,
                colorPalette: resources.colorPalette,
                visibleIndices: resources.culling?.visibleIndices,
                indirectArguments: resources.culling?.indirectArguments,
                count: count,
                visibility: visibility,
                lod: resources.lod,
                interpolation: interpolation,
                viewProjection: camera.viewProjection,
                into: encoder
            )
        case .billboard:
            billboards.encode(
                displacements: resources.displacements,
                displacementScale: particleBuffers.displacementScale,
                currentPositions: resources.currentPositions,
                colorIndices: resources.colorIndices,
                colorPalette: resources.colorPalette,
                visibleIndices: resources.culling?.visibleIndices,
                indirectArguments: resources.culling?.indirectArguments,
                count: count,
                visibility: visibility,
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
        resources.counts?.didSubmit(count: count)
        buffers.didSubmit()
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
