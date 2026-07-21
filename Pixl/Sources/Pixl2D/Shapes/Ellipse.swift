/// Ellipse geometry measured in local units.
public struct Ellipse: Hashable, Sendable {
    /// Explicit width and height, or `nil` for unit sizing.
    public let size: Vec2?
    /// Creates a unit-sized ellipse.
    public init() { size = nil }
    /// Creates an ellipse.
    /// - Parameters:
    ///   - width: Positive width.
    ///   - height: Positive height.
    public init(width: Double, height: Double) {
        precondition(width.isFinite && width > 0 && height.isFinite && height > 0)
        size = .init(width, height)
    }
    /// Unit-sized ellipse.
    public static var ellipse: Self { .init() }
    /// Explicitly sized ellipse.
    /// - Parameters:
    ///   - width: Positive width in local units.
    ///   - height: Positive height in local units.
    public static func ellipse(width: Double, height: Double) -> Self { .init(width: width, height: height) }
}
