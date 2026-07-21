/// Rhombus geometry measured tip-to-tip in local units.
public struct Rhombus: Hashable, Sendable {
    /// Explicit tip-to-tip size, or `nil` for unit sizing.
    public let size: Vec2?
    /// Creates a unit-sized rhombus.
    public init() { size = nil }
    /// Creates an explicitly sized rhombus.
    /// - Parameters:
    ///   - width: Positive horizontal tip-to-tip size.
    ///   - height: Positive vertical tip-to-tip size.
    public init(width: Double, height: Double) {
        precondition(width.isFinite && width > 0 && height.isFinite && height > 0)
        size = .init(width, height)
    }
    /// Unit-sized rhombus.
    public static var rhombus: Self { .init() }
    /// Explicitly sized rhombus.
    /// - Parameters:
    ///   - width: Positive horizontal tip-to-tip size.
    ///   - height: Positive vertical tip-to-tip size.
    public static func rhombus(width: Double, height: Double) -> Self { .init(width: width, height: height) }
}
