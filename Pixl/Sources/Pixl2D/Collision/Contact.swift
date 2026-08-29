import Swift

public struct Contact2D: Sendable, Equatable {
    public let normal: Vec2
    public let depth: Float

    public init(normal: Vec2, depth: Float) {
        self.normal = normal
        self.depth = depth
    }
}
