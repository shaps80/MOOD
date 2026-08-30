import Swift

/// Local-space capsule formed by sweeping a circle along a finite segment.
public struct Capsule2D: Hashable, Sendable {
    /// Segment joining the centres of the two round caps.
    public let segment: Segment
    /// Radius around the complete segment.
    public let radius: Float

    /// Creates a capsule around a finite segment.
    public init(segment: Segment, radius: Float) {
        precondition(
            radius.isFinite && radius > 0,
            "Capsule2D requires a positive finite radius"
        )
        self.segment = segment
        self.radius = radius
    }

    /// Creates a centred vertical capsule from its complete exterior size.
    ///
    /// Height must exceed width. Use ``Circle2D`` when both are equal.
    public init(center: Vec2 = .zero, size: Size) {
        precondition(
            center.isValid
                && size.isValid
                && size.x > 0
                && size.y > size.x,
            "Capsule2D requires finite positive dimensions with height greater than width"
        )
        let radius = size.x * 0.5
        let halfSegment = (size.y * 0.5) - radius
        self.init(
            segment: Segment(
                start: center - Vec2(0, halfSegment),
                end: center + Vec2(0, halfSegment)
            ),
            radius: radius
        )
    }

    /// Local-space axis-aligned bounds enclosing the capsule.
    public var bounds: Rect {
        let minimum = Vec2(
            Swift.min(segment.start.x, segment.end.x) - radius,
            Swift.min(segment.start.y, segment.end.y) - radius
        )
        let maximum = Vec2(
            Swift.max(segment.start.x, segment.end.x) + radius,
            Swift.max(segment.start.y, segment.end.y) + radius
        )
        return Rect(origin: minimum, size: maximum - minimum)
    }
}
