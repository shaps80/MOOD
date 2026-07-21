/// Analytic heart geometry.
public struct Heart: Hashable, Sendable {
    /// Explicit width, or `nil` for canonical unit sizing.
    public let width: Double?
    /// Creates a unit-sized heart.
    public init() { width = nil }
    /// Creates a heart with an explicit width.
    /// - Parameter width: Positive width in local units.
    public init(width: Double) { precondition(width.isFinite && width > 0); self.width = width }
    /// Unit-sized heart.
    public static var heart: Self { .init() }
    /// Explicitly sized heart.
    /// - Parameter width: Positive width in local units.
    public static func heart(width: Double) -> Self { .init(width: width) }
}
