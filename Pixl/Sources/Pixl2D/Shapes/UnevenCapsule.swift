/// Vertical capsule with independently sized end radii.
public struct UnevenCapsule: Hashable, Sendable {
    /// Bottom radius.
    public let bottomRadius: Float
    /// Top radius.
    public let topRadius: Float
    /// Distance between cap centres.
    public let height: Float
    /// Creates a canonical unit uneven capsule.
    public init() { self.init(bottomRadius: 0.3, topRadius: 0.15, height: 0.55) }
    /// Creates an uneven capsule.
    /// - Parameters:
    ///   - bottomRadius: Positive bottom radius.
    ///   - topRadius: Positive top radius.
    ///   - height: Positive distance between cap centres, greater than their radius difference.
    public init(bottomRadius: Float, topRadius: Float, height: Float) {
        precondition(bottomRadius.isFinite && bottomRadius > 0 && topRadius.isFinite && topRadius > 0)
        precondition(height.isFinite && height > abs(bottomRadius - topRadius))
        self.bottomRadius = bottomRadius; self.topRadius = topRadius; self.height = height
    }
    /// Canonical uneven capsule.
    public static var unevenCapsule: Self { .init() }
    /// Explicit uneven capsule.
    /// - Parameters:
    ///   - bottomRadius: Positive bottom radius.
    ///   - topRadius: Positive top radius.
    ///   - height: Positive cap-centre distance greater than the radius difference.
    public static func unevenCapsule(bottomRadius: Float, topRadius: Float, height: Float) -> Self {
        .init(bottomRadius: bottomRadius, topRadius: topRadius, height: height)
    }
}
