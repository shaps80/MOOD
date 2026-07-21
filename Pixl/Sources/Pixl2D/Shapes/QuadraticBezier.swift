/// Quadratic Bézier curve defined by three local control points.
public struct QuadraticBezier: Hashable, Sendable {
    /// First endpoint.
    public let start: Vec2
    /// Quadratic control point.
    public let control: Vec2
    /// Second endpoint.
    public let end: Vec2
    /// Creates a canonical arching unit Bézier.
    public init() { self.init(start: .init(-0.5, -0.5), control: .init(0, 0.5), end: .init(0.5, -0.5)) }
    /// Creates a quadratic Bézier.
    /// - Parameters:
    ///   - start: First finite endpoint.
    ///   - control: Finite control point.
    ///   - end: Second finite endpoint.
    public init(start: Vec2, control: Vec2, end: Vec2) {
        precondition([start.x, start.y, control.x, control.y, end.x, end.y].allSatisfy(\.isFinite))
        precondition(start != end)
        self.start = start; self.control = control; self.end = end
    }
    /// Canonical arching unit quadratic Bézier.
    public static var quadraticBezier: Self { .init() }
    /// Quadratic Bézier defined by three local points.
    /// - Parameters:
    ///   - start: First finite endpoint.
    ///   - control: Finite control point.
    ///   - end: Second finite endpoint.
    public static func quadraticBezier(from start: Vec2, control: Vec2, to end: Vec2) -> Self {
        .init(start: start, control: control, end: end)
    }
}
