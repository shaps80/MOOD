/// Six-pointed star geometry measured in local units.
public struct Hexagram: Hashable, Sendable {
    /// Explicit circumradius, or `nil` for unit sizing.
    public let radius: Double?
    /// Creates a unit-sized hexagram.
    public init() { radius = nil }
    /// Creates a hexagram with an explicit circumradius.
    /// - Parameter radius: Positive circumradius in local units.
    public init(radius: Double) { precondition(radius.isFinite && radius > 0); self.radius = radius }
    /// Unit-sized hexagram.
    public static var hexagram: Self { .init() }
    /// Explicitly sized hexagram.
    /// - Parameter radius: Positive circumradius in local units.
    public static func hexagram(radius: Double) -> Self { .init(radius: radius) }
}
