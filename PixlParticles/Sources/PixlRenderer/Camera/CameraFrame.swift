import Swift

public struct CameraFrame: BitwiseCopyable, Sendable {
    public let viewProjection: Matrix4x4
    public let position: SIMD4<Float>
    public let right: SIMD4<Float>
    public let up: SIMD4<Float>
    public let viewport: SIMD4<Float>

    public init(
        viewProjection: Matrix4x4,
        position: SIMD3<Float>,
        right: SIMD3<Float>,
        up: SIMD3<Float>,
        viewport: ViewportSize
    ) {
        self.viewProjection = viewProjection
        self.position = SIMD4<Float>(position, 1)
        self.right = SIMD4<Float>(right, 0)
        self.up = SIMD4<Float>(up, 0)
        self.viewport = [
            Float(viewport.width),
            Float(viewport.height),
            viewport.width > 0 ? 1 / Float(viewport.width) : 0,
            viewport.height > 0 ? 1 / Float(viewport.height) : 0,
        ]
    }

    public var viewportSize: ViewportSize {
        .init(width: UInt32(viewport.x), height: UInt32(viewport.y))
    }
}
