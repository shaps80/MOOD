/// Regular octagon geometry measured in local units.
public struct Octagon: Hashable, Sendable {
    /// Explicit circumradius, or `nil` for unit sizing.
    public let radius: Double?
    /// Creates a unit-sized regular octagon.
    public init() { radius = nil }
    /// Creates a regular octagon with an explicit circumradius.
    /// - Parameter radius: Positive circumradius in local units.
    public init(radius: Double) { precondition(radius.isFinite && radius > 0); self.radius = radius }
    /// Unit-sized regular octagon.
    public static var octagon: Self { .init() }
    /// Explicitly sized regular octagon.
    /// - Parameter radius: Positive circumradius in local units.
    public static func octagon(radius: Double) -> Self { .init(radius: radius) }
}
