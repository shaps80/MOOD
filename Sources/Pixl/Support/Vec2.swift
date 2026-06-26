import Swift

public struct Vec2: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero: Self = .init(
        x: .zero,
        y: .zero
    )
}
