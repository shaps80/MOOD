/// Rounded X geometry.
public struct RoundedX: Hashable, Sendable {
    /// Diagonal reach.
    public let width: Float
    /// Lobe radius.
    public let rounding: Float
    /// Creates a canonical unit rounded X.
    public init() { self.init(width: 0.7, rounding: 0.1) }
    /// Creates a rounded X.
    /// - Parameters:
    ///   - width: Positive diagonal reach.
    ///   - rounding: Positive lobe radius.
    public init(width: Float, rounding: Float) {
        precondition(width.isFinite && width > 0 && rounding.isFinite && rounding > 0)
        self.width = width; self.rounding = rounding
    }
    /// Canonical unit rounded-X geometry.
    public static var roundedX: Self { .init() }
    /// Rounded-X geometry with explicit reach and rounding.
    /// - Parameters:
    ///   - width: Positive diagonal reach.
    ///   - rounding: Positive lobe radius.
    public static func roundedX(width: Float, rounding: Float) -> Self { .init(width: width, rounding: rounding) }
}
