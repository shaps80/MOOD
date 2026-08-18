import Swift

/// Constant particle-property values lowered for one draw.
public struct ParticleRenderValues: Equatable, Sendable {
    public var size: SIMD2<Float>
    public var rotation: Float

    public init(
        size: SIMD2<Float> = [1, 2],
        rotation: Float = 0
    ) {
        precondition(size.x >= 0 && size.y >= 0)
        precondition(size.x.isFinite && size.y.isFinite)
        precondition(rotation.isFinite)
        self.size = size
        self.rotation = rotation
    }
}
