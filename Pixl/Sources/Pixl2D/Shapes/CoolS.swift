/// Stylized S-curve geometry from the IQ fixed-parameter catalogue.
public struct CoolS: Hashable, Sendable {
    /// Overall local-space size.
    public let size: Double
    /// Creates a unit-sized S curve.
    public init() { size = 1 }
    /// Creates an S curve.
    /// - Parameter size: Positive overall size in local units.
    public init(size: Double) { precondition(size.isFinite && size > 0); self.size = size }
    /// Canonical unit stylized-S geometry.
    public static var coolS: Self { .init() }
    /// Stylized-S geometry with an explicit size.
    /// - Parameter size: Positive overall local-space size.
    public static func coolS(size: Double) -> Self { .init(size: size) }
}
