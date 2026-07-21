/// Centred isosceles trapezoid geometry.
public struct Trapezoid: Hashable, Sendable {
    /// Bottom width in local units.
    public let bottomWidth: Double
    /// Top width in local units.
    public let topWidth: Double
    /// Height in local units.
    public let height: Double

    /// Creates a canonical unit trapezoid.
    public init() { self.init(bottomWidth: 1, topWidth: 0.5, height: 1) }
    /// Creates an isosceles trapezoid.
    /// - Parameters:
    ///   - bottomWidth: Positive bottom width.
    ///   - topWidth: Positive top width.
    ///   - height: Positive height.
    public init(bottomWidth: Double, topWidth: Double, height: Double) {
        precondition(bottomWidth.isFinite && bottomWidth > 0)
        precondition(topWidth.isFinite && topWidth > 0)
        precondition(height.isFinite && height > 0)
        self.bottomWidth = bottomWidth; self.topWidth = topWidth; self.height = height
    }
    /// Canonical unit trapezoid.
    public static var trapezoid: Self { .init() }
    /// Explicitly sized trapezoid.
    /// - Parameters:
    ///   - bottomWidth: Positive bottom width.
    ///   - topWidth: Positive top width.
    ///   - height: Positive height.
    public static func trapezoid(bottomWidth: Double, topWidth: Double, height: Double) -> Self {
        .init(bottomWidth: bottomWidth, topWidth: topWidth, height: height)
    }
}
