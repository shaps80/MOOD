public final class ComposedDeviceBackend<Composition: RenderComposition>: Backend {
    private let renderer: DeviceRenderer
    public let composition: Composition

    public var pointLOD: PointLOD {
        get { renderer.pointLOD }
        set { renderer.pointLOD = newValue }
    }
    public var cullingBounds: CullingBounds {
        get { renderer.cullingBounds }
        set { renderer.cullingBounds = newValue }
    }
    public var capturesDiagnostics: Bool {
        get { renderer.capturesDiagnostics }
        set { renderer.capturesDiagnostics = newValue }
    }
    public var visibleCount: Int? { renderer.visibleCount }
    public var cpuRenderTime: Double? { renderer.cpuRenderTime }
    public var onGPUTime: (@Sendable (Double?) -> Void)? {
        get { renderer.onGPUTime }
        set { renderer.onGPUTime = newValue }
    }
    public var onPresented: (@Sendable (Double) -> Void)? {
        get { renderer.onPresented }
        set { renderer.onPresented = newValue }
    }

    public init(
        platform: any Platform,
        composition: Composition,
        pointLOD: PointLOD = .init()
    ) throws {
        renderer = try DeviceRenderer(platform: platform, pointLOD: pointLOD)
        self.composition = composition
    }

    public func renderParticles(
        count: Int,
        buffers: ParticleBuffers,
        renderer: ParticleRenderer,
        values: ParticleRenderValues,
        interpolation: Float,
        cullingViewProjection: Matrix4x4,
        camera: CameraFrame
    ) throws {
        try self.renderer.renderParticles(
            count: count,
            buffers: buffers,
            renderer: renderer,
            values: values,
            interpolation: interpolation,
            cullingViewProjection: cullingViewProjection,
            camera: camera,
            composition: composition
        )
    }
}
