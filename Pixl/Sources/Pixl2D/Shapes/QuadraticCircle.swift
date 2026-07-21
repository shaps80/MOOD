/// Unit quadratic-circle geometry from the IQ fixed-parameter catalogue.
public struct QuadraticCircle: Hashable, Sendable {
    /// Overall local-space size.
    public let size: Double
    /// Creates a unit-sized quadratic circle.
    public init() { size = 1 }
    /// Creates a quadratic circle.
    /// - Parameter size: Positive overall size in local units.
    public init(size: Double) { precondition(size.isFinite && size > 0); self.size = size }
    /// Canonical unit quadratic-circle geometry.
    public static var quadraticCircle: Self { .init() }
    /// Quadratic-circle geometry with an explicit size.
    /// - Parameter size: Positive overall local-space size.
    public static func quadraticCircle(size: Double) -> Self { .init(size: size) }
}
