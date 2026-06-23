import Swift

public struct Camera: Equatable, Sendable {
    public internal(set) var origin: Vec2
    public let viewportSize: Vec2

    public init(origin: Vec2 = .zero, viewportSize: Vec2) {
        self.origin = origin
        self.viewportSize = viewportSize
    }

    public var visibleBounds: Rect {
        Rect(origin: origin, size: viewportSize)
    }
}
