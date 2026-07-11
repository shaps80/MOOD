import Swift

/// A render-space transform for drawing an item around its center.
///
/// `RenderTransform` stores the values a renderer needs directly: center,
/// size, and rotation. Scale remains a sprite/entity concern; render size is
/// already resolved before this type is created.
///
/// ```swift
/// let transform = RenderTransform(
///     center: Vec2(x: 100, y: 80),
///     size: Vec2(x: 32, y: 32),
///     rotation: .degrees(45)
/// )
/// ```
public struct RenderTransform: Equatable, Sendable {
    /// The item center in world or render coordinates.
    public var center: Vec2

    /// The resolved item size.
    public var size: Vec2

    /// The clockwise rotation in y-down coordinates.
    public var rotation: Angle

    /// Creates a render transform.
    public init(
        center: Vec2,
        size: Vec2,
        rotation: Angle = .zero
    ) {
        self.center = center
        self.size = size
        self.rotation = rotation
    }

    /// The unrotated axis-aligned rectangle for this transform.
    ///
    /// ```swift
    /// let rect = transform.rect
    /// ```
    public var rect: Rect {
        Rect(center: center, size: size)
    }

    /// The axis-aligned rectangle enclosing the rotated transform.
    ///
    /// Use this for culling and camera bounds where a simple world-space AABB is
    /// needed even when the item rotates visually.
    ///
    /// ```swift
    /// let bounds = transform.rotatedBounds
    /// ```
    public var rotatedBounds: Rect {
        let components = sincos(rotation)
        let c = abs(components.cos)
        let s = abs(components.sin)
        let rotatedSize = Vec2(
            x: (size.x * c) + (size.y * s),
            y: (size.x * s) + (size.y * c)
        )

        return Rect(center: center, size: rotatedSize)
    }
}
