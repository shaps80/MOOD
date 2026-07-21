/// Equilateral triangle geometry.
public struct EquilateralTriangle: Hashable, Sendable {
    /// Explicit side length, or `nil` for unit sizing.
    public let side: Float?
    /// Creates a unit-sided equilateral triangle.
    public init() { side = nil }
    /// Creates an equilateral triangle.
    /// - Parameter side: Positive side length in local units.
    public init(side: Float) { precondition(side.isFinite && side > 0); self.side = side }
    /// Unit-sided equilateral triangle.
    public static var equilateralTriangle: Self { .init() }
    /// Explicitly sized equilateral triangle.
    /// - Parameter side: Positive side length in local units.
    public static func equilateralTriangle(side: Float) -> Self { .init(side: side) }
}
