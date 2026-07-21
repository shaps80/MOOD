/// Regular star geometry.
public struct Star: Hashable, Sendable {
    /// Circumradius.
    public let radius: Float
    /// Number of points.
    public let points: UInt32
    /// Inner-radius ratio in `0...1`.
    public let innerRadius: Float
    /// Creates a canonical five-pointed unit star.
    public init() { self.init(radius: 0.5, points: 5, innerRadius: 0.45) }
    /// Creates a regular star.
    /// - Parameters:
    ///   - radius: Positive circumradius.
    ///   - points: Point count of at least three.
    ///   - innerRadius: Inner radius as a ratio of `radius`, strictly within `0...1`.
    public init(radius: Float, points: UInt32 = 5, innerRadius: Float = 0.45) {
        precondition(radius.isFinite && radius > 0 && points >= 3)
        precondition(innerRadius.isFinite && innerRadius > 0 && innerRadius < 1)
        self.radius = radius; self.points = points; self.innerRadius = innerRadius
    }
    /// Canonical five-pointed unit star.
    public static var star: Self { .init() }
    /// Explicit regular star.
    /// - Parameters:
    ///   - radius: Positive circumradius.
    ///   - points: Point count of at least three.
    ///   - innerRadius: Inner-radius ratio strictly within `0...1`.
    public static func star(radius: Float, points: UInt32 = 5, innerRadius: Float = 0.45) -> Self {
        .init(radius: radius, points: points, innerRadius: innerRadius)
    }
}
