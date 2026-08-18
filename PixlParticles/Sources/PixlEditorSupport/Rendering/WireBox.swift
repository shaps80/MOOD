import Swift

public struct WireBox: Sendable {
    public var isVisible: Bool
    public var center: SIMD3<Float>
    public var size: SIMD3<Float>
    public var color: SIMD4<Float>

    public init(
        isVisible: Bool = false,
        center: SIMD3<Float> = .zero,
        size: SIMD3<Float> = .zero,
        color: SIMD4<Float> = [1, 1, 0, 1]
    ) {
        precondition(size.x >= 0 && size.y >= 0 && size.z >= 0)
        self.isVisible = isVisible
        self.center = center
        self.size = size
        self.color = color
    }
}
