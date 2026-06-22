import Swift

/// Resolves movement against collidable world geometry.
///
/// `CollisionWorld` is intentionally separate from `Entity`.
///
/// - `Entity` stores state: position, size, velocity, optional collider.
/// - `CollisionWorld` knows how to query world colliders and resolve movement.
///
/// Movement is resolved one axis at a time:
///
/// ```text
/// 1. Try horizontal movement.
/// 2. If blocked, clamp X to the obstacle edge and zero X velocity.
/// 3. Try vertical movement from the resolved X position.
/// 4. If blocked, clamp Y to the obstacle edge and zero Y velocity.
/// ```
///
/// This gives the normal "slide along walls" behavior:
///
/// ```text
/// Desired move: down-right into a wall
///
///        wall
///        ####
///   @ -> ####   X blocked
///   v          Y still moves, so player slides down the wall
/// ```
///
/// Current broad phase is tile-grid based: only tile cells touched by the
/// proposed bounds are checked. This avoids scanning the whole tilemap.
struct CollisionWorld {
    /// Collision-facing view of a tilemap.
    private let colliderIndex: Tilemap.ColliderIndex
    let delta: Double

    init(tilemap: Tilemap, delta: Double) {
        self.colliderIndex = tilemap.colliderIndex
        self.delta = max(delta, 0)
    }

    /// Moves an entity by velocity for this world's delta.
    ///
    /// Entities without colliders move freely. Entities with colliders use
    /// axis-separated collision resolution against the tilemap collider index.
    func move(entity: inout Entity, velocity proposedVelocity: Vec2) {
        guard let collider = entity.collider else {
            entity.move(
                to: Vec2(
                    x: entity.position.x + (proposedVelocity.x * delta),
                    y: entity.position.y + (proposedVelocity.y * delta)
                ),
                velocity: proposedVelocity
            )
            return
        }

        var velocity = proposedVelocity
        var position = entity.position

        let horizontal = resolveHorizontalMovement(
            from: position,
            distance: velocity.x * delta,
            collider: collider
        )
        position = Vec2(x: horizontal.value, y: position.y)

        let vertical = resolveVerticalMovement(
            from: position,
            distance: velocity.y * delta,
            collider: collider
        )
        position = Vec2(x: position.x, y: vertical.value)

        if horizontal.blocked {
            velocity = Vec2(x: 0, y: velocity.y)
        }

        if vertical.blocked {
            velocity = Vec2(x: velocity.x, y: 0)
        }

        entity.move(to: position, velocity: velocity)
    }

    /// Resolves X movement against any tile colliders touched by the proposed
    /// horizontal bounds.
    private func resolveHorizontalMovement(
        from position: Vec2,
        distance: Double,
        collider: Collider
    ) -> AxisResolution {
        guard distance != 0 else {
            return AxisResolution(value: position.x, blocked: false)
        }

        let proposedPosition = Vec2(x: position.x + distance, y: position.y)
        let proposedBounds = collider.worldBounds(at: proposedPosition)
        var resolvedX = proposedPosition.x
        var blocked = false

        colliderIndex.forEach(intersecting: proposedBounds) { tileCollider in
            let obstacle = tileCollider.bounds
            guard proposedBounds.intersects(obstacle) else { return }

            blocked = true
            if distance > 0 {
                // Moving right: place the collider's right edge on obstacle left.
                resolvedX = min(resolvedX, obstacle.minX - collider.bounds.maxX)
            } else {
                // Moving left: place the collider's left edge on obstacle right.
                resolvedX = max(resolvedX, obstacle.maxX - collider.bounds.minX)
            }
        }

        return AxisResolution(value: resolvedX, blocked: blocked)
    }

    /// Resolves Y movement after X has already been resolved.
    private func resolveVerticalMovement(
        from position: Vec2,
        distance: Double,
        collider: Collider
    ) -> AxisResolution {
        guard distance != 0 else {
            return AxisResolution(value: position.y, blocked: false)
        }

        let proposedPosition = Vec2(x: position.x, y: position.y + distance)
        let proposedBounds = collider.worldBounds(at: proposedPosition)
        var resolvedY = proposedPosition.y
        var blocked = false

        colliderIndex.forEach(intersecting: proposedBounds) { tileCollider in
            let obstacle = tileCollider.bounds
            guard proposedBounds.intersects(obstacle) else { return }

            blocked = true
            if distance > 0 {
                // Moving down: place the collider's bottom edge on obstacle top.
                resolvedY = min(resolvedY, obstacle.minY - collider.bounds.maxY)
            } else {
                // Moving up: place the collider's top edge on obstacle bottom.
                resolvedY = max(resolvedY, obstacle.maxY - collider.bounds.minY)
            }
        }

        return AxisResolution(value: resolvedY, blocked: blocked)
    }
}

/// Result of resolving movement along one axis.
private struct AxisResolution {
    let value: Double
    let blocked: Bool
}
