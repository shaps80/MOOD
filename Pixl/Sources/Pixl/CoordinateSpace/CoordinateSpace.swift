import Swift

/// A stored coordinate-space value used to resolve gameplay positions.
///
/// Pixl uses a y-down coordinate model. Every coordinate space uses a top-left
/// origin. Spawn APIs resolve positions into world-space top-left points for
/// the spawned entity.
///
/// ```swift
/// context.spawn(Bullet.self, at: .zero)
/// context.spawn(Bullet.self, at: Vec2(x: 80, y: 24), in: .screen)
/// context.spawn(Bullet.self, at: Vec2(x: 0, y: -24), in: .entity(playerID))
/// ```
public enum CoordinateSpace: Equatable, Sendable {
    /// World coordinates.
    case world

    /// Screen coordinates relative to the current camera viewport.
    case screen

    /// Coordinates relative to an entity's top-left local bounds.
    case entity
}

extension CoordinateSpace: CoordinateSpaceProtocol {
    public var coordinateSpace: CoordinateSpace {
        self
    }
}
