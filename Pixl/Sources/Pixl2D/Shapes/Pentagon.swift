/// Regular pentagon geometry measured in local units.
public struct Pentagon: Hashable, Sendable {
    /// Explicit circumradius, or `nil` for unit sizing.
    public let radius: Double?

    /// Creates a unit-sized regular pentagon.
    public init() { radius = nil }

    /// Creates a regular pentagon with an explicit circumradius.
    /// - Parameter radius: Positive circumradius in local units.
    public init(radius: Double) {
        precondition(radius.isFinite && radius > 0)
        self.radius = radius
    }

    /// Unit-sized regular pentagon.
    public static var pentagon: Self { .init() }
    /// Explicitly sized regular pentagon.
    /// - Parameter radius: Positive circumradius in local units.
    public static func pentagon(radius: Double) -> Self { .init(radius: radius) }
}
