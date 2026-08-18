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

    public func renderPoints(
        count: Int,
        buffers: PointBuffers,
        interpolation: Float,
        cullingViewProjection: Matrix4x4,
        viewProjection: Matrix4x4,
        viewport: ViewportSize
    ) throws {
        try renderer.renderPoints(
            count: count,
            buffers: buffers,
            interpolation: interpolation,
            cullingViewProjection: cullingViewProjection,
            viewProjection: viewProjection,
            viewport: viewport,
            composition: composition
        )
    }
}
