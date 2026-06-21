import Swift

public struct Rect: Equatable, Sendable {
    public var origin: Vec2
    public var size: Vec2

    public init(origin: Vec2, size: Vec2) {
        self.origin = origin
        self.size = size
    }

    public static let zero: Self = .init(
        origin: .zero,
        size: .zero
    )
}
