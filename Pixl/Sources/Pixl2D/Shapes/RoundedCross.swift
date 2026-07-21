/// Rounded diagonal-lobed cross geometry.
public struct RoundedCross: Hashable, Sendable {
    /// Positive diagonal-lobe height.
    public let height: Double
    /// Creates a canonical unit rounded cross.
    public init() { height = 0.5 }
    /// Creates a rounded cross.
    /// - Parameter height: Positive shape parameter.
    public init(height: Double) { precondition(height.isFinite && height > 0); self.height = height }
    /// Canonical unit rounded-cross geometry.
    public static var roundedCross: Self { .init() }
    /// Rounded-cross geometry with an explicit lobe height.
    /// - Parameter height: Positive diagonal-lobe height.
    public static func roundedCross(height: Double) -> Self { .init(height: height) }
}
