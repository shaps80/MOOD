/// Axis-aligned rectangle geometry measured in local units.
public struct Rectangle: Hashable, Sendable {
    /// Explicit local size, or `nil` for a canonical `1 × 1` rectangle.
    public let size: Vec2?

    /// Creates a canonical unit rectangle.
    public init() { size = nil }

    /// Creates an explicitly sized rectangle.
    /// - Parameters:
    ///   - width: Positive width in local units.
    ///   - height: Positive height in local units.
    public init(width: Float, height: Float) {
        precondition(width.isFinite && width > 0)
        precondition(height.isFinite && height > 0)
        size = .init(width, height)
    }

    /// Canonical unit rectangle used by `Shape(.rect)`.
    public static var rect: Self { .init() }

    /// Explicitly sized rectangle used by `Shape(.rect(width:height:))`.
    /// - Parameters:
    ///   - width: Positive width in local units.
    ///   - height: Positive height in local units.
    public static func rect(width: Float, height: Float) -> Self {
        .init(width: width, height: height)
    }
}
