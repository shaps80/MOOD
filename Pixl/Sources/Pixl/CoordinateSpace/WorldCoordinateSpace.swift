import Swift

/// World-space coordinates.
///
/// World coordinates use Pixl's y-down game world with a top-left origin.
/// Spawning in world space is the default, and spawn positions place the
/// spawned entity's top-left at the supplied point.
///
/// ```swift
/// context.spawn(Bullet.self, at: Vec2(x: 120, y: 48))
/// context.spawn(Bullet.self, at: Vec2(x: 120, y: 48), in: .world)
/// ```
public struct WorldCoordinateSpace: CoordinateSpaceProtocol, Equatable, Sendable {
    /// Creates the typed world coordinate-space marker.
    public init() {}

    /// The stored `.world` representation.
    public var coordinateSpace: CoordinateSpace {
        .world
    }
}
