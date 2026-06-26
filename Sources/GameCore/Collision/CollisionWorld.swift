import Swift

/// Resolves movement against collidable world geometry.
///
/// `CollisionWorld` is intentionally separate from `Entity`.
///
/// - `Entity` stores state: position, size, velocity, colliders.
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
/// proposed bounds are checked. Entity colliders are currently checked as a
/// flat list because the active entity count is still small.
struct CollisionWorld {
    /// Collision-facing view of a tilemap.
    private let colliderIndex: Tilemap.ColliderIndex
    private let entityColliders: [Collider]
    let delta: Double

    init(tilemap: Tilemap, entityColliders: [Collider] = [], delta: Double) {
        self.colliderIndex = tilemap.colliderIndex
        self.entityColliders = entityColliders
        self.delta = max(delta, 0)
    }

    /// Moves an entity by velocity for this world's delta.
    ///
    /// Entities without colliders move freely. Entities with colliders use
    /// axis-separated collision resolution against the tilemap collider index.
    func move(entity: inout Entity, velocity proposedVelocity: Vec2) {
        guard !entity.colliders.isEmpty else {
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
            colliders: entity.colliders
        )
        position = Vec2(x: horizontal.value, y: position.y)

        let vertical = resolveVerticalMovement(
            from: position,
            distance: velocity.y * delta,
            colliders: entity.colliders
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
        colliders: [Collider]
    ) -> AxisResolution {
        guard distance != 0 else {
            return AxisResolution(value: position.x, blocked: false)
        }

        let proposedPosition = Vec2(x: position.x + distance, y: position.y)
        var resolvedX = proposedPosition.x
        var blocked = false

        for collider in colliders {
            let previousBounds = collider.worldBounds(at: position)
            let proposedBounds = collider.worldBounds(at: proposedPosition)

            forEachObstacle(intersecting: proposedBounds) { obstacleCollider in
                let obstacle = obstacleCollider.bounds
                guard proposedBounds.intersects(obstacle),
                      collider.behaviour == .blocking,
                      collider.canCollide(with: obstacleCollider),
                      obstacleCollider.behaviour == .blocking,
                      shouldBlockHorizontalMovement(
                          distance: distance,
                          from: previousBounds,
                          to: proposedBounds,
                          obstacle: obstacleCollider
                      )
                else {
                    return
                }

                blocked = true
                if distance > 0 {
                    // Moving right: place the collider's right edge on obstacle left.
                    resolvedX = min(resolvedX, obstacle.minX - collider.bounds.maxX)
                } else {
                    // Moving left: place the collider's left edge on obstacle right.
                    resolvedX = max(resolvedX, obstacle.maxX - collider.bounds.minX)
                }
            }
        }

        return AxisResolution(value: resolvedX, blocked: blocked)
    }

    /// Resolves Y movement after X has already been resolved.
    private func resolveVerticalMovement(
        from position: Vec2,
        distance: Double,
        colliders: [Collider]
    ) -> AxisResolution {
        guard distance != 0 else {
            return AxisResolution(value: position.y, blocked: false)
        }

        let proposedPosition = Vec2(x: position.x, y: position.y + distance)
        var resolvedY = proposedPosition.y
        var blocked = false

        for collider in colliders {
            let previousBounds = collider.worldBounds(at: position)
            let proposedBounds = collider.worldBounds(at: proposedPosition)

            forEachObstacle(intersecting: proposedBounds) { obstacleCollider in
                let obstacle = obstacleCollider.bounds
                guard proposedBounds.intersects(obstacle),
                      collider.behaviour == .blocking,
                      collider.canCollide(with: obstacleCollider),
                      obstacleCollider.behaviour == .blocking,
                      shouldBlockVerticalMovement(
                          distance: distance,
                          from: previousBounds,
                          to: proposedBounds,
                          obstacle: obstacleCollider
                      )
                else {
                    return
                }

                blocked = true
                if distance > 0 {
                    // Moving down: place the collider's bottom edge on obstacle top.
                    resolvedY = min(resolvedY, obstacle.minY - collider.bounds.maxY)
                } else {
                    // Moving up: place the collider's top edge on obstacle bottom.
                    resolvedY = max(resolvedY, obstacle.maxY - collider.bounds.minY)
                }
            }
        }

        return AxisResolution(value: resolvedY, blocked: blocked)
    }

    private func forEachObstacle(
        intersecting bounds: Rect,
        _ body: (Collider) -> Void
    ) {
        colliderIndex.forEach(intersecting: bounds, body)

        for collider in entityColliders where collider.bounds.intersects(bounds) {
            body(collider)
        }
    }

    private func shouldBlockHorizontalMovement(
        distance: Double,
        from previousBounds: Rect,
        to proposedBounds: Rect,
        obstacle: Collider
    ) -> Bool {
        guard let oneWay = obstacle.oneWay else {
            return true
        }

        let margin = oneWay.margin

        if distance > 0 {
            return oneWay.face == .left
                && previousBounds.maxX <= obstacle.bounds.minX + margin
                && proposedBounds.maxX >= obstacle.bounds.minX
        } else {
            return oneWay.face == .right
                && previousBounds.minX >= obstacle.bounds.maxX - margin
                && proposedBounds.minX <= obstacle.bounds.maxX
        }
    }

    private func shouldBlockVerticalMovement(
        distance: Double,
        from previousBounds: Rect,
        to proposedBounds: Rect,
        obstacle: Collider
    ) -> Bool {
        guard let oneWay = obstacle.oneWay else {
            return true
        }

        let margin = oneWay.margin

        if distance > 0 {
            return oneWay.face == .top
                && previousBounds.maxY <= obstacle.bounds.minY + margin
                && proposedBounds.maxY >= obstacle.bounds.minY
        } else {
            return oneWay.face == .bottom
                && previousBounds.minY >= obstacle.bounds.maxY - margin
                && proposedBounds.minY <= obstacle.bounds.maxY
        }
    }
}

/// Result of resolving movement along one axis.
private struct AxisResolution {
    let value: Double
    let blocked: Bool
}

private extension Collider {
    func canCollide(with other: Collider) -> Bool {
        mask.contains(.init(other.layer))
    }
}
