import Swift

public struct CameraFrustum: Sendable {
    public var isVisible: Bool
    public var isPerspective: Bool
    public var position: SIMD3<Float>
    public var inverseViewProjection: Matrix4x4

    public init(
        isVisible: Bool = false,
        isPerspective: Bool = true,
        position: SIMD3<Float> = .zero,
        inverseViewProjection: Matrix4x4 = .identity
    ) {
        self.isVisible = isVisible
        self.isPerspective = isPerspective
        self.position = position
        self.inverseViewProjection = inverseViewProjection
    }
}
