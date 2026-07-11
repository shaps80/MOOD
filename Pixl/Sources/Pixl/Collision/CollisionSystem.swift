import Swift

/// Resolves movement and detects contacts against collidable game geometry.
///
/// `CollisionSystem` is intentionally separate from `EntityState`.
///
/// - `EntityState` stores state: transform, velocity, colliders.
/// - `CollisionSystem` knows how to query colliders and resolve movement.
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
/// This is the pre-physics movement model, adapted to current transform-aware
/// colliders.
struct CollisionSystem {
    /// Collision-facing view of a tilemap.
    private let colliderIndex: Tilemap.ColliderIndex
    private let entities: EntityStore
    let delta: Double

    init(tilemap: Tilemap, entities: EntityStore, delta: Double) {
        self.colliderIndex = tilemap.colliderIndex
        self.entities = entities
        self.delta = max(delta, 0)
    }

    /// Moves entity state by velocity for this world's delta.
    ///
    /// Entities without colliders move freely. Entities with colliders use
    /// axis-separated collision resolution against the tilemap collider index.
    func move(state: inout EntityState, velocity proposedVelocity: Vec2) {
        guard !state.colliders.isEmpty else {
            state.move(
                to: Vec2(
                    x: state.transform.position.x + (proposedVelocity.x * delta),
                    y: state.transform.position.y + (proposedVelocity.y * delta)
                ),
                velocity: proposedVelocity
            )
            return
        }

        var velocity = proposedVelocity
        var position = state.transform.position

        let horizontal = resolveHorizontalMovement(
            entityID: state.id,
            state: state,
            from: position,
            distance: velocity.x * delta
        )
        position = Vec2(x: horizontal.value, y: position.y)

        let vertical = resolveVerticalMovement(
            entityID: state.id,
            state: state,
            from: position,
            distance: velocity.y * delta
        )
        position = Vec2(x: position.x, y: vertical.value)

        if horizontal.blocked {
            velocity = Vec2(x: 0, y: velocity.y)
        }

        if vertical.blocked {
            velocity = Vec2(x: velocity.x, y: 0)
        }

        resolveShapeContacts(
            entityID: state.id,
            state: state,
            position: &position,
            velocity: &velocity
        )

        state.move(to: position, velocity: velocity)
    }

    func detectContacts(into contacts: ContactState) {
        entities.forEachCollider { entityID, colliderIndex, collider in
            forEachCollider(intersecting: collider.bounds) { reference, other in
                guard reference.entityID != entityID,
                      collider.canCollide(with: other),
                      collider.bounds.intersects(other.bounds)
                else {
                    return
                }

                contacts.record(
                    source: Contact.Endpoint(
                        id: entityID,
                        collider: colliderIndex
                    ),
                    target: reference.target
                )
            }
        }
    }

    /// Resolves X movement against any colliders touched by proposed bounds.
    private func resolveHorizontalMovement(
        entityID: EntityID,
        state: EntityState,
        from position: Vec2,
        distance: Double
    ) -> AxisResolution {
        guard distance != 0 else {
            return AxisResolution(value: position.x, blocked: false)
        }

        let proposedPosition = Vec2(x: position.x + distance, y: position.y)
        var resolvedX = proposedPosition.x
        var blocked = false

        let previousColliders = placedColliders(for: state, at: position)
        let proposedColliders = placedColliders(for: state, at: proposedPosition)

        for index in proposedColliders.indices {
            let collider = proposedColliders[index]
            guard collider.behaviour == .blocking else {
                continue
            }

            let previousBounds = previousColliders[index].bounds
            let proposedBounds = collider.bounds

            forEachCollider(intersecting: proposedBounds) { reference, otherCollider in
                guard reference.entityID != entityID,
                      canBlockMovement(
                          collider,
                          against: otherCollider,
                          proposedBounds: proposedBounds
                      ),
                      shouldBlockHorizontalMovement(
                          distance: distance,
                          from: previousBounds,
                          to: proposedBounds,
                          other: otherCollider
                      )
                else {
                    return
                }

                blocked = true
                if distance > 0 {
                    resolvedX = min(resolvedX, proposedPosition.x + otherCollider.bounds.minX - proposedBounds.maxX)
                } else {
                    resolvedX = max(resolvedX, proposedPosition.x + otherCollider.bounds.maxX - proposedBounds.minX)
                }
            }
        }

        return AxisResolution(value: resolvedX, blocked: blocked)
    }

    /// Resolves Y movement after X has already been resolved.
    private func resolveVerticalMovement(
        entityID: EntityID,
        state: EntityState,
        from position: Vec2,
        distance: Double
    ) -> AxisResolution {
        guard distance != 0 else {
            return AxisResolution(value: position.y, blocked: false)
        }

        let proposedPosition = Vec2(x: position.x, y: position.y + distance)
        var resolvedY = proposedPosition.y
        var blocked = false

        let previousColliders = placedColliders(for: state, at: position)
        let proposedColliders = placedColliders(for: state, at: proposedPosition)

        for index in proposedColliders.indices {
            let collider = proposedColliders[index]
            guard collider.behaviour == .blocking else {
                continue
            }

            let previousBounds = previousColliders[index].bounds
            let proposedBounds = collider.bounds

            forEachCollider(intersecting: proposedBounds) { reference, otherCollider in
                guard reference.entityID != entityID,
                      canBlockMovement(
                          collider,
                          against: otherCollider,
                          proposedBounds: proposedBounds
                      ),
                      shouldBlockVerticalMovement(
                          distance: distance,
                          from: previousBounds,
                          to: proposedBounds,
                          other: otherCollider
                      )
                else {
                    return
                }

                blocked = true
                if distance > 0 {
                    resolvedY = min(resolvedY, proposedPosition.y + otherCollider.bounds.minY - proposedBounds.maxY)
                } else {
                    resolvedY = max(resolvedY, proposedPosition.y + otherCollider.bounds.maxY - proposedBounds.minY)
                }
            }
        }

        return AxisResolution(value: resolvedY, blocked: blocked)
    }

    private func forEachCollider(
        intersecting bounds: Rect,
        _ body: (ColliderReference, Collider) -> Void
    ) {
        colliderIndex.forEach(intersecting: bounds) { tile, collider in
            body(.tile(tile), collider)
        }

        entities.forEachCollider { entityID, colliderIndex, collider in
            guard collider.bounds.intersects(bounds) else {
                return
            }

            body(.entity(entityID, colliderIndex), collider)
        }
    }

    private func canBlockMovement(
        _ collider: Collider,
        against other: Collider,
        proposedBounds: Rect
    ) -> Bool {
        collider.isAxisAligned
            && other.isAxisAligned
            && other.behaviour == .blocking
            && collider.canCollide(with: other)
            && proposedBounds.intersects(other.bounds)
    }

    private func resolveShapeContacts(
        entityID: EntityID,
        state: EntityState,
        position: inout Vec2,
        velocity: inout Vec2
    ) {
        let maxIterations = 2

        for _ in 0..<maxIterations {
            var didResolve = false

            for collider in placedColliders(for: state, at: position) {
                guard collider.behaviour == .blocking else {
                    continue
                }

                forEachCollider(intersecting: collider.bounds) { reference, otherCollider in
                    guard reference.entityID != entityID,
                          shouldResolveShapeContact(collider, against: otherCollider),
                          let resolution = collider.collisionResolution(against: otherCollider)
                    else {
                        return
                    }

                    position += resolution.vector
                    velocity = velocity.sliding(along: resolution.normal)
                    didResolve = true
                }
            }

            if !didResolve {
                break
            }
        }
    }

    private func shouldResolveShapeContact(
        _ collider: Collider,
        against other: Collider
    ) -> Bool {
        guard !collider.isAxisAligned || !other.isAxisAligned else {
            return false
        }

        return other.behaviour == .blocking
            && other.oneWay == nil
            && collider.canCollide(with: other)
            && collider.bounds.intersects(other.bounds)
    }

    private func shouldBlockHorizontalMovement(
        distance: Double,
        from previousBounds: Rect,
        to proposedBounds: Rect,
        other: Collider
    ) -> Bool {
        guard let oneWay = other.oneWay else {
            return true
        }

        let margin = oneWay.margin

        if distance > 0 {
            return oneWay.face == .left
                && previousBounds.maxX <= other.bounds.minX + margin
                && proposedBounds.maxX >= other.bounds.minX
        } else {
            return oneWay.face == .right
                && previousBounds.minX >= other.bounds.maxX - margin
                && proposedBounds.minX <= other.bounds.maxX
        }
    }

    private func shouldBlockVerticalMovement(
        distance: Double,
        from previousBounds: Rect,
        to proposedBounds: Rect,
        other: Collider
    ) -> Bool {
        guard let oneWay = other.oneWay else {
            return true
        }

        let margin = oneWay.margin

        if distance > 0 {
            return oneWay.face == .top
                && previousBounds.maxY <= other.bounds.minY + margin
                && proposedBounds.maxY >= other.bounds.minY
        } else {
            return oneWay.face == .bottom
                && previousBounds.minY >= other.bounds.maxY - margin
                && proposedBounds.minY <= other.bounds.maxY
        }
    }

    private func placedColliders(for state: EntityState, at position: Vec2) -> [Collider] {
        let spriteSize = state.sprite?.naturalSize ?? .zero
        var transform = state.transform
        transform.position = position

        return state.colliders.map {
            $0.placed(
                in: transform,
                spriteSize: spriteSize
            )
        }
    }
}

/// Result of resolving movement along one axis.
private struct AxisResolution {
    let value: Double
    let blocked: Bool
}

private enum ColliderReference {
    case entity(EntityID, Int)
    case tile(Contact.TileEndpoint)

    var entityID: EntityID? {
        guard case .entity(let id, _) = self else {
            return nil
        }

        return id
    }

    var target: Contact.Target {
        switch self {
        case .entity(let id, let collider):
            return .entity(
                Contact.Endpoint(
                    id: id,
                    collider: collider
                )
            )
        case .tile(let endpoint):
            return .tile(endpoint)
        }
    }
}

private extension Collider {
    func canCollide(with other: Collider) -> Bool {
        mask.contains(.init(other.layer))
    }

    var isAxisAligned: Bool {
        rotation.radians.magnitude < 0.000001
    }
}

private extension Vec2 {
    func sliding(along normal: Vec2) -> Vec2 {
        let amount = dot(normal)

        guard amount < 0 else {
            return self
        }

        return self - (normal * amount)
    }
}
