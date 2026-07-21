/// Rounded X geometry.
public struct RoundedX: Hashable, Sendable {
    /// Diagonal reach.
    public let width: Double
    /// Lobe radius.
    public let rounding: Double
    /// Creates a canonical unit rounded X.
    public init() { self.init(width: 0.7, rounding: 0.1) }
    /// Creates a rounded X.
    /// - Parameters:
    ///   - width: Positive diagonal reach.
    ///   - rounding: Positive lobe radius.
    public init(width: Double, rounding: Double) {
        precondition(width.isFinite && width > 0 && rounding.isFinite && rounding > 0)
        self.width = width; self.rounding = rounding
    }
    /// Canonical unit rounded-X geometry.
    public static var roundedX: Self { .init() }
    /// Rounded-X geometry with explicit reach and rounding.
    /// - Parameters:
    ///   - width: Positive diagonal reach.
    ///   - rounding: Positive lobe radius.
    public static func roundedX(width: Double, rounding: Double) -> Self { .init(width: width, rounding: rounding) }
}
