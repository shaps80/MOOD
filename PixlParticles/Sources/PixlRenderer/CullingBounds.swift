import Swift

public struct CullingBounds: Sendable {
    public var isEnabled: Bool
    public var scale: Float
    public var baseHeight: Float

    public init(
        isEnabled: Bool = false,
        scale: Float = 300,
        baseHeight: Float = -100
    ) {
        precondition(scale >= 1)
        self.isEnabled = isEnabled
        self.scale = scale
        self.baseHeight = baseHeight
    }
}
