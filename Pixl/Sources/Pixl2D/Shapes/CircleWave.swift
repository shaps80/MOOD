/// Repeating circular-wave geometry.
public struct CircleWave: Hashable, Sendable {
    /// Centre-line radius.
    public let radius: Float
    /// Full wave width.
    public let width: Float
    /// Creates a canonical unit circle wave.
    public init() { self.init(radius: 0.4, width: 0.1) }
    /// Creates a circle wave.
    /// - Parameters:
    ///   - radius: Positive wave radius.
    ///   - width: Positive line width.
    public init(radius: Float, width: Float) {
        precondition(radius.isFinite && radius > 0 && width.isFinite && width > 0)
        self.radius = radius; self.width = width
    }
    /// Canonical unit circle-wave geometry.
    public static var circleWave: Self { .init() }
    /// Circle-wave geometry with explicit radius and width.
    /// - Parameters:
    ///   - radius: Positive centre-line radius.
    ///   - width: Positive full wave width.
    public static func circleWave(radius: Float, width: Float) -> Self { .init(radius: radius, width: width) }
}
