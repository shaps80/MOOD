import Swift

public struct Rect: Equatable, Sendable {
    public var origin: Vec2
    public var size: Vec2

    public init(origin: Vec2, size: Vec2) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(
            origin: Vec2(x: x, y: y),
            size: Vec2(x: width, y: height)
        )
    }

    public static let zero: Self = .init(
        origin: .zero,
        size: .zero
    )
}
