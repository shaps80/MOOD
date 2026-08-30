/// Local-space circle geometry reusable by collision and rendering.
public struct Circle2D: Hashable, Sendable {
    /// Centre in local coordinates.
    public let center: Vec2
    /// Radius in local units.
    public let radius: Float

    /// Creates a circle with a finite centre and positive radius.
    public init(center: Vec2 = .zero, radius: Float) {
        precondition(
            center.isValid && radius.isFinite && radius > 0,
            "Circle2D requires a finite centre and positive radius"
        )
        self.center = center
        self.radius = radius
    }

    /// Local-space axis-aligned bounds enclosing the circle.
    public var bounds: Rect {
        Rect(
            center: center,
            size: .init(repeating: radius * 2)
        )
    }
}
