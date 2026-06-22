import Swift

/// Axis-aligned collision bounds attached to something in the world.
///
/// A collider stores bounds in **local space**. Local space means the rect is
/// relative to the owner, not the whole world.
///
/// Example: player entity at world position `(100, 40)`.
///
/// ```text
/// World space
///
///   x=100
///     |
///     v
///     +---------------- entity ----------------+
///     |                                        |
///     |   collider bounds: (4, 8, 24, 20)      |
///     |                                        |
///     +----------------------------------------+
///
/// Local collider:
///   minX = 4, maxX = 28
///   minY = 8, maxY = 28
///
/// World collider:
///   minX = 104, maxX = 128
///   minY = 48,  maxY = 68
/// ```
///
/// Keeping bounds local makes the collider move with its owner automatically:
/// update the entity position, then call `worldBounds(at:)` when collision
/// code needs the absolute rect.
public struct Collider: Equatable, Sendable {
    /// Local-space AABB, relative to the owning entity or tile origin.
    public var bounds: Rect

    public init(bounds: Rect) {
        self.bounds = bounds
    }

    /// Converts local bounds into world-space bounds at an owner position.
    public func worldBounds(at position: Vec2) -> Rect {
        bounds.translated(by: position)
    }
}
