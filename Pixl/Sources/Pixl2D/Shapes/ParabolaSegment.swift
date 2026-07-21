/// Filled finite parabolic segment.
public struct ParabolaSegment: Hashable, Sendable {
    /// Full base width.
    public let width: Double
    /// Apex height.
    public let height: Double
    /// Creates a unit parabolic segment.
    public init() { self.init(width: 1, height: 1) }
    /// Creates a parabolic segment.
    /// - Parameters:
    ///   - width: Positive full width.
    ///   - height: Positive height.
    public init(width: Double, height: Double) {
        precondition(width.isFinite && width > 0 && height.isFinite && height > 0)
        self.width = width; self.height = height
    }
    /// Canonical unit parabolic-segment geometry.
    public static var parabolaSegment: Self { .init() }
    /// Parabolic-segment geometry with explicit dimensions.
    /// - Parameters:
    ///   - width: Positive full base width.
    ///   - height: Positive apex height.
    public static func parabolaSegment(width: Double, height: Double) -> Self { .init(width: width, height: height) }
}
