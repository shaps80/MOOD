import PixlMath

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

public extension Segment {
    /// Whether `point` lies exactly on this finite segment, including either endpoint.
    func contains(_ point: Vec2) -> Bool {
        guard point.x.isFinite, point.y.isFinite,
              cross(end - start, point - start) == 0
        else { return false }

        return point.x >= Swift.min(start.x, end.x)
            && point.x <= Swift.max(start.x, end.x)
            && point.y >= Swift.min(start.y, end.y)
            && point.y <= Swift.max(start.y, end.y)
    }

    /// Whether this finite segment crosses, touches, or collinearly overlaps `other`.
    func intersects(_ other: Segment) -> Bool {
        let direction = end - start
        let otherDirection = other.end - other.start
        let firstStart = cross(direction, other.start - start)
        let firstEnd = cross(direction, other.end - start)
        let secondStart = cross(otherDirection, start - other.start)
        let secondEnd = cross(otherDirection, end - other.start)

        if firstStart == 0, contains(other.start) { return true }
        if firstEnd == 0, contains(other.end) { return true }
        if secondStart == 0, other.contains(start) { return true }
        if secondEnd == 0, other.contains(end) { return true }
        return (firstStart < 0) != (firstEnd < 0)
            && (secondStart < 0) != (secondEnd < 0)
    }
}
