/// Circle geometry measured in local units.
public struct Circle: Hashable, Sendable {
    /// Explicit radius, or `nil` for a canonical unit circle with radius `0.5`.
    public let radius: Float?

    /// Creates a canonical unit circle.
    public init() { radius = nil }

    /// Creates a circle with an explicit positive local-space radius.
    /// - Parameter radius: Positive radius in local units.
    public init(radius: Float) {
        precondition(radius.isFinite && radius > 0)
        self.radius = radius
    }

    /// Canonical unit circle used by `Shape(.circle)`.
    public static var circle: Self { .init() }

    /// Explicitly sized circle used by `Shape(.circle(radius: 20))`.
    /// - Parameter radius: Positive radius in local units.
    public static func circle(radius: Float) -> Self { .init(radius: radius) }
}
