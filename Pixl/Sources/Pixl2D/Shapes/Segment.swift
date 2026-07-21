/// Finite line-segment geometry in local coordinates.
public struct Segment: Hashable, Sendable {
    /// First endpoint.
    public let start: Vec2
    /// Second endpoint.
    public let end: Vec2

    /// Creates a horizontal unit segment centred at the local origin.
    public init() { self.init(start: .init(-0.5, 0), end: .init(0.5, 0)) }

    /// Creates a segment between two distinct finite endpoints.
    /// - Parameters:
    ///   - start: First local endpoint.
    ///   - end: Second local endpoint.
    public init(start: Vec2, end: Vec2) {
        precondition(start.x.isFinite && start.y.isFinite && end.x.isFinite && end.y.isFinite)
        precondition(start != end)
        self.start = start
        self.end = end
    }

    /// Horizontal unit segment.
    public static var segment: Self { .init() }
    /// Segment between two local endpoints.
    /// - Parameters:
    ///   - start: First finite endpoint.
    ///   - end: Distinct finite endpoint.
    public static func segment(from start: Vec2, to end: Vec2) -> Self {
        .init(start: start, end: end)
    }
}
