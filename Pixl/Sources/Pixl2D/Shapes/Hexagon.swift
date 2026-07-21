/// Regular hexagon geometry measured in local units.
public struct Hexagon: Hashable, Sendable {
    /// Explicit circumradius, or `nil` for unit sizing.
    public let radius: Float?
    /// Creates a unit-sized regular hexagon.
    public init() { radius = nil }
    /// Creates a regular hexagon with an explicit circumradius.
    /// - Parameter radius: Positive circumradius in local units.
    public init(radius: Float) { precondition(radius.isFinite && radius > 0); self.radius = radius }
    /// Unit-sized regular hexagon.
    public static var hexagon: Self { .init() }
    /// Explicitly sized regular hexagon.
    /// - Parameter radius: Positive circumradius in local units.
    public static func hexagon(radius: Float) -> Self { .init(radius: radius) }
}
