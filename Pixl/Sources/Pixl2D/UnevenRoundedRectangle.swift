/// Axis-aligned rectangle geometry with independent continuous corner radii.
public struct UnevenRoundedRectangle: Hashable, Sendable {
    /// Explicit local size, or `nil` for a canonical `1 × 1` rectangle.
    public let size: Vec2?
    public var cornerRadii: RectangleCornerRadii

    public init(cornerRadii: RectangleCornerRadii) {
        size = nil
        self.cornerRadii = cornerRadii
    }

    public init(
        topLeadingRadius: Float,
        bottomLeadingRadius: Float,
        bottomTrailingRadius: Float,
        topTrailingRadius: Float
    ) {
        self.init(cornerRadii: .init(
            topLeading: topLeadingRadius,
            bottomLeading: bottomLeadingRadius,
            bottomTrailing: bottomTrailingRadius,
            topTrailing: topTrailingRadius
        ))
    }

    public init(width: Float, height: Float, cornerRadii: RectangleCornerRadii) {
        precondition(width.isFinite && width > 0)
        precondition(height.isFinite && height > 0)
        size = .init(width, height)
        self.cornerRadii = cornerRadii
    }
}
