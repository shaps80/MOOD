/// Axis-aligned cross geometry.
public struct Cross: Hashable, Sendable {
    /// Arm reach and arm half-thickness.
    public let size: Vec2
    /// Creates a canonical unit cross.
    public init() { self.init(width: 0.5, height: 0.2) }
    /// Creates a cross from arm reach and half-thickness.
    /// - Parameters:
    ///   - width: Positive arm reach.
    ///   - height: Positive arm half-thickness no greater than `width`.
    public init(width: Double, height: Double) {
        precondition(width.isFinite && width > 0 && height.isFinite && height > 0 && height <= width)
        size = .init(width, height)
    }
    /// Canonical unit cross geometry.
    public static var cross: Self { .init() }
    /// Cross geometry with explicit arm reach and half-thickness.
    /// - Parameters:
    ///   - width: Positive arm reach.
    ///   - height: Positive arm half-thickness.
    public static func cross(width: Double, height: Double) -> Self { .init(width: width, height: height) }
}
