import Swift

/// Coordinates relative to an entity's top-left local bounds.
///
/// Entity coordinates use a top-left origin. A point of `.zero` means the
/// target entity's top-left corner. Spawn APIs place the spawned entity's
/// top-left at the resolved point.
///
/// ```swift
/// let abovePlayer = Vec2(x: 0, y: -enemySize.y)
/// context.spawn(Enemy.self, at: abovePlayer, in: .entity(playerID))
/// ```
public struct EntityCoordinateSpace: CoordinateSpaceProtocol, Equatable, Sendable {
    public let id: EntityID

    public init(_ id: EntityID) {
        self.id = id
    }

    public var coordinateSpace: CoordinateSpace {
        .entity(id)
    }
}

public extension CoordinateSpaceProtocol where Self == EntityCoordinateSpace {
    /// Coordinates relative to an entity's top-left local bounds.
    ///
    /// ```swift
    /// context.spawn(Bullet.self, at: Vec2(x: 8, y: -8), in: .entity(playerID))
    /// ```
    static func entity(_ id: EntityID) -> EntityCoordinateSpace {
        EntityCoordinateSpace(id)
    }
}
