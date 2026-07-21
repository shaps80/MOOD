/// Angled ring segment geometry.
public struct Ring: Hashable, Sendable {
    /// Centre-line radius.
    public let radius: Float
    /// Full radial width.
    public let width: Float
    /// Normalized cut direction.
    public let direction: Vec2
    /// Creates a canonical unit ring.
    public init() { self.init(radius: 0.4, width: 0.1, direction: .init(1, 1)) }
    /// Creates a ring segment.
    /// - Parameters:
    ///   - radius: Positive centre-line radius.
    ///   - width: Positive full radial width.
    ///   - direction: Nonzero finite cut direction.
    public init(radius: Float, width: Float, direction: Vec2) {
        precondition(radius.isFinite && radius > 0 && width.isFinite && width > 0)
        guard let direction = direction.normalized else { preconditionFailure("Ring direction must be nonzero") }
        self.radius = radius; self.width = width; self.direction = direction
    }
    /// Canonical unit ring.
    public static var ring: Self { .init() }
    /// Explicit ring segment.
    /// - Parameters:
    ///   - radius: Positive centre-line radius.
    ///   - width: Positive full radial width.
    ///   - direction: Nonzero finite cut direction.
    public static func ring(radius: Float, width: Float, direction: Vec2 = .init(1, 0)) -> Self {
        .init(radius: radius, width: width, direction: direction)
    }
}
