import Swift

/// Resolves movement and detects contacts against collidable game geometry.
///
/// `CollisionSystem` is intentionally separate from `EntityState`.
///
/// - `EntityState` stores state: position, size, velocity, colliders.
/// - `CollisionSystem` knows how to query colliders and resolve movement.
///
/// Current broad phase is tile-grid based: only tile cells touched by the
/// proposed bounds are checked. EntityState colliders are currently checked as a
/// flat list because the active entity count is still small.
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

        let proposedPosition = Vec2(
            x: state.transform.position.x + (proposedVelocity.x * delta),
            y: state.transform.position.y + (proposedVelocity.y * delta)
        )
        let resolution = resolveMovement(
            entityID: state.id,
            from: state.transform.position,
            to: proposedPosition,
            state: state
        )

        state.move(to: resolution.position, velocity: resolution.velocity)
    }

    func detectContacts(into contacts: ContactState) {
        entities.forEachCollider { entityID, colliderIndex, collider in
            forEachCollider(intersecting: collider.bounds) { otherEntityID, otherColliderIndex, other in
                guard let otherEntityID,
                      let otherColliderIndex,
                      otherEntityID != entityID,
                      collider.canCollide(with: other),
                      collider.bounds.intersects(other.bounds),
                      collider.collisionResolution(against: other) != nil
                else {
                    return
                }

                contacts.record(
                    source: Contact.Endpoint(
                        id: entityID,
                        collider: colliderIndex
                    ),
                    target: Contact.Endpoint(
                        id: otherEntityID,
                        collider: otherColliderIndex
                    )
                )
            }
        }
    }

    private func resolveMovement(
        entityID: EntityID,
        from previousPosition: Vec2,
        to proposedPosition: Vec2,
        state: EntityState
    ) -> MovementResolution {
        let delta = proposedPosition - previousPosition
        var position = proposedPosition
        var velocity = state.velocity
        let maxIterations = 4

        for _ in 0..<maxIterations {
            var didResolve = false

            for collider in placedColliders(for: state, at: position) {
                guard collider.behaviour == .blocking else {
                    continue
                }

                let previousCollider = collider.placedForMovement(
                    from: position,
                    to: previousPosition
                )

                forEachCollider(intersecting: collider.bounds) { otherEntityID, _, otherCollider in
                    guard otherEntityID != entityID,
                          let resolution = canResolveMovement(
                              collider,
                              against: otherCollider,
                              previousCollider: previousCollider,
                              movement: delta
                          )
                    else {
                        return
                    }

                    let axisCorrection = axisAlignedCorrection(
                        collider,
                        against: otherCollider,
                        movement: delta
                    )
                    let correction = axisCorrection ?? resolution.vector
                    position += correction
                    velocity = if let axisCorrection {
                        velocity.resolved(
                            afterAxisCorrection: axisCorrection,
                            friction: otherCollider.friction
                        )
                    } else {
                        velocity.sliding(
                            along: resolution.normal,
                            friction: otherCollider.friction
                        )
                    }
                    didResolve = true
                }
            }

            if !didResolve {
                break
            }
        }

        return MovementResolution(position: position, velocity: velocity)
    }

    private func forEachCollider(
        intersecting bounds: Rect,
        _ body: (EntityID?, Int?, Collider) -> Void
    ) {
        colliderIndex.forEach(intersecting: bounds) { collider in
            body(nil, nil, collider)
        }

        entities.forEachCollider { entityID, colliderIndex, collider in
            guard collider.bounds.intersects(bounds) else {
                return
            }

            body(entityID, colliderIndex, collider)
        }
    }

    private func canResolveMovement(
        _ collider: Collider,
        against other: Collider,
        previousCollider: Collider,
        movement: Vec2
    ) -> CollisionResolution? {
        guard other.behaviour == .blocking,
              collider.canCollide(with: other),
              collider.bounds.intersects(other.bounds),
              shouldBlockMovement(
                  movement: movement,
                  from: previousCollider,
                  to: collider,
                  other: other
              )
        else {
            return nil
        }

        return collider.collisionResolution(against: other)
    }

    private func axisAlignedCorrection(
        _ collider: Collider,
        against other: Collider,
        movement: Vec2
    ) -> Vec2? {
        guard collider.isAxisAligned, other.isAxisAligned else {
            return nil
        }

        let horizontal: Vec2?
        if movement.x > 0 {
            horizontal = Vec2(x: other.bounds.minX - collider.bounds.maxX, y: 0)
        } else if movement.x < 0 {
            horizontal = Vec2(x: other.bounds.maxX - collider.bounds.minX, y: 0)
        } else {
            horizontal = nil
        }

        let vertical: Vec2?
        if movement.y > 0 {
            vertical = Vec2(x: 0, y: other.bounds.minY - collider.bounds.maxY)
        } else if movement.y < 0 {
            vertical = Vec2(x: 0, y: other.bounds.maxY - collider.bounds.minY)
        } else {
            vertical = nil
        }

        switch (horizontal, vertical) {
        case (.some(let horizontal), .some(let vertical)):
            return horizontal.length <= vertical.length ? horizontal : vertical
        case (.some(let horizontal), .none):
            return horizontal
        case (.none, .some(let vertical)):
            return vertical
        case (.none, .none):
            return nil
        }
    }

    private func shouldBlockMovement(
        movement: Vec2,
        from previousCollider: Collider,
        to proposedCollider: Collider,
        other: Collider
    ) -> Bool {
        guard let oneWay = other.oneWay else {
            return true
        }

        if !previousCollider.isAxisAligned || !proposedCollider.isAxisAligned || !other.isAxisAligned {
            assertionFailure("One-way colliders only support axis-aligned collision.")
            return true
        }

        let margin = oneWay.margin
        let previousBounds = previousCollider.bounds
        let proposedBounds = proposedCollider.bounds

        if movement.x > 0 {
            if oneWay.face == .left,
               previousBounds.maxX <= other.bounds.minX + margin,
               proposedBounds.maxX >= other.bounds.minX {
                return true
            }
        } else if movement.x < 0 {
            if oneWay.face == .right,
               previousBounds.minX >= other.bounds.maxX - margin,
               proposedBounds.minX <= other.bounds.maxX {
                return true
            }
        }

        if movement.y > 0 {
            return oneWay.face == .top
                && previousBounds.maxY <= other.bounds.minY + margin
                && proposedBounds.maxY >= other.bounds.minY
        } else if movement.y < 0 {
            return oneWay.face == .bottom
                && previousBounds.minY >= other.bounds.maxY - margin
                && proposedBounds.minY <= other.bounds.maxY
        }

        return false
    }

    private func placedColliders(for state: EntityState, at position: Vec2) -> [Collider] {
        let spriteSize = state.sprite?.naturalSize ?? .zero
        var transform = state.transform
        transform.position = position

        return state.colliders.map {
            $0.placed(
                in: transform,
                spriteSize: spriteSize,
            )
        }
    }
}

private struct MovementResolution {
    let position: Vec2
    let velocity: Vec2
}

private extension Collider {
    func canCollide(with other: Collider) -> Bool {
        mask.contains(.init(other.layer))
    }

    var isAxisAligned: Bool {
        rotation.radians.magnitude < 0.000001
    }

    func placedForMovement(from currentPosition: Vec2, to previousPosition: Vec2) -> Collider {
        var collider = self
        let offset = previousPosition - currentPosition
        collider.shapeFrame = shapeFrame.translated(by: offset)
        collider.bounds = collider.shapeFrame.rotatedBounds(rotation)
        return collider
    }
}

private extension Vec2 {
    func resolved(afterAxisCorrection correction: Vec2, friction: Double) -> Vec2 {
        let projected = Vec2(
            x: correction.x == 0 ? x : 0,
            y: correction.y == 0 ? y : 0
        )

        return projected.applyingTangentialFriction(friction, originalSpeed: length)
    }

    func sliding(along normal: Vec2, friction: Double) -> Vec2 {
        let amount = dot(normal)

        guard amount < 0 else {
            return self
        }

        let projected = self - (normal * amount)

        return projected.applyingTangentialFriction(friction, originalSpeed: length)
    }

    func applyingTangentialFriction(_ friction: Double, originalSpeed: Double) -> Vec2 {
        guard let direction = normalized else {
            return self
        }

        let friction = max(0, friction)
        let projectedSpeed = length
        let preservedSpeed = originalSpeed

        if friction <= 1 {
            let speed = preservedSpeed + ((projectedSpeed - preservedSpeed) * friction)
            return direction * speed
        }

        return direction * max(0, projectedSpeed / friction)
    }
}
