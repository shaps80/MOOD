import Pixl2D
import Testing

private extension CollisionLayer {
    static let analyticSource: Self = 10
    static let analyticTarget: Self = 11
}

@Suite("Analytic collision shapes")
struct AnalyticCollisionTests {
    @Test
    func circleContactsRectangleWithExactCurvedDepth() throws {
        let world = CollisionWorld2D()
        let source = world.insert(
            Circle2D(center: .init(5, 5), radius: 5),
            mode: .dynamic,
            layer: .analyticSource,
            mask: CollisionMask(.analyticTarget)
        )
        _ = world.insert(
            bounds: Rect(x: 8, y: 0, width: 10, height: 10),
            mode: .static,
            layer: .analyticTarget,
            mask: .none
        )

        let collision = try #require(firstCollision(in: world))

        #expect(collision.source.collider == source)
        #expect(collision.contact?.normal == .init(1, 0))
        #expect(collision.contact?.depth == 2)
    }

    @Test
    func circlesContactAnalytically() throws {
        let world = CollisionWorld2D()
        _ = world.insert(
            Circle2D(radius: 5),
            mode: .dynamic,
            layer: .analyticSource,
            mask: CollisionMask(.analyticTarget)
        )
        _ = world.insert(
            Circle2D(center: .init(8, 0), radius: 5),
            mode: .static,
            layer: .analyticTarget,
            mask: .none
        )

        let contact = try #require(firstCollision(in: world)?.contact)

        #expect(contact.normal == .init(1, 0))
        #expect(contact.depth == 2)
    }

    @Test
    func capsuleContactsRectangleAlongItsStraightSide() throws {
        let world = CollisionWorld2D()
        _ = world.insert(
            Capsule2D(center: .init(5, 5), size: .init(4, 10)),
            mode: .dynamic,
            layer: .analyticSource,
            mask: CollisionMask(.analyticTarget)
        )
        _ = world.insert(
            bounds: Rect(x: 6, y: 0, width: 10, height: 10),
            mode: .static,
            layer: .analyticTarget,
            mask: .none
        )

        let contact = try #require(firstCollision(in: world)?.contact)

        #expect(contact.normal == .init(1, 0))
        #expect(contact.depth == 1)
    }

    @Test
    func circleContactsCapsuleCap() throws {
        let world = CollisionWorld2D()
        _ = world.insert(
            Circle2D(center: .init(2.5, 0), radius: 2),
            mode: .dynamic,
            layer: .analyticSource,
            mask: CollisionMask(.analyticTarget)
        )
        _ = world.insert(
            Capsule2D(center: .zero, size: .init(2, 6)),
            mode: .static,
            layer: .analyticTarget,
            mask: .none
        )

        let contact = try #require(firstCollision(in: world)?.contact)

        #expect(contact.normal == .init(-1, 0))
        #expect(contact.depth == 0.5)
    }

    @Test
    func parallelCapsulesContactAlongTheirSides() throws {
        let world = CollisionWorld2D()
        _ = world.insert(
            Capsule2D(center: .zero, size: .init(2, 6)),
            mode: .dynamic,
            layer: .analyticSource,
            mask: CollisionMask(.analyticTarget)
        )
        _ = world.insert(
            Capsule2D(center: .init(1.5, 0), size: .init(2, 6)),
            mode: .static,
            layer: .analyticTarget,
            mask: .none
        )

        let contact = try #require(firstCollision(in: world)?.contact)

        #expect(contact.normal == .init(1, 0))
        #expect(contact.depth == 0.5)
    }

    @Test
    func capsuleContactsPolygonUsingSlopeNormal() throws {
        let world = CollisionWorld2D()
        _ = world.insert(
            Capsule2D(center: .init(-1, 0), size: .init(2, 4)),
            mode: .dynamic,
            layer: .analyticSource,
            mask: CollisionMask(.analyticTarget)
        )
        _ = world.insert(
            Polygon2D(
                Vec2(-10, -10),
                Vec2(10, -10),
                Vec2(10, 10)
            ),
            mode: .static,
            layer: .analyticTarget,
            mask: .none
        )

        let contact = try #require(firstCollision(in: world)?.contact)
        let expected = Float(0.5).squareRoot()

        #expect(abs(contact.normal.x - expected) < 0.0001)
        #expect(abs(contact.normal.y + expected) < 0.0001)
    }

    @Test
    func transformedCircleCachesExactWorldBounds() {
        let world = CollisionWorld2D()
        let circle = world.insert(
            Circle2D(center: .init(1, 0), radius: 2),
            transform: Transform2D(
                .init(10, 20),
                rotation: .pi / 2,
                scale: .init(repeating: 2)
            ),
            mode: .static,
            layer: .analyticTarget,
            mask: .none
        )

        #expect(
            world.bounds(for: circle)
                == Rect(x: 6, y: 18, width: 8, height: 8)
        )
    }

    @Test
    func transformedCapsuleCachesExactWorldBounds() {
        let world = CollisionWorld2D()
        let capsule = world.insert(
            Capsule2D(center: .zero, size: .init(2, 6)),
            transform: Transform2D(
                .init(10, 20),
                rotation: .pi / 2,
                scale: .init(repeating: 2)
            ),
            mode: .static,
            layer: .analyticTarget,
            mask: .none
        )

        #expect(
            world.bounds(for: capsule)
                == Rect(x: 4, y: 18, width: 12, height: 4)
        )
    }

    @Test
    func capsuleUpdateReusesColliderIdentityAndRebuildsBounds() {
        let world = CollisionWorld2D()
        let capsule = world.insert(
            Capsule2D(center: .zero, size: .init(4, 10)),
            transform: Transform2D(.init(10, 20)),
            mode: .dynamic,
            layer: .analyticTarget,
            mask: .none
        )

        world.update(
            capsule,
            capsule: Capsule2D(center: .init(0, -2), size: .init(4, 6)),
            transform: Transform2D(.init(10, 20))
        )

        #expect(world.count == 1)
        #expect(
            world.bounds(for: capsule)
                == Rect(x: 8, y: 15, width: 4, height: 6)
        )
    }

    @Test
    func queryRejectsCircleBoundsCorner() {
        let world = CollisionWorld2D()
        _ = world.insert(
            Circle2D(radius: 5),
            mode: .static,
            layer: .analyticTarget,
            mask: .none
        )
        var found = false

        world.query(
            overlapping: Rect(x: 4.5, y: 4.5, width: 0.4, height: 0.4),
            mask: CollisionMask(.analyticTarget)
        ) { _ in
            found = true
            return true
        }

        #expect(!found)
    }

    @Test
    func rayHitsCircleBeforeItsCentre() throws {
        let world = CollisionWorld2D()
        let circle = world.insert(
            Circle2D(center: .init(10, 0), radius: 2),
            mode: .static,
            layer: .analyticTarget,
            mask: .none
        )

        let hit = try #require(world.rayCast(
            Ray2D(origin: .zero, direction: .init(1, 0)),
            mask: CollisionMask(.analyticTarget)
        ))

        #expect(hit.collider == circle)
        #expect(hit.hit.distance == 8)
        #expect(hit.hit.normal == .init(-1, 0))
    }

    @Test
    func rayHitsCapsuleStraightSide() throws {
        let world = CollisionWorld2D()
        let capsule = world.insert(
            Capsule2D(center: .init(10, 0), size: .init(4, 10)),
            mode: .static,
            layer: .analyticTarget,
            mask: .none
        )

        let hit = try #require(world.rayCast(
            Ray2D(origin: .zero, direction: .init(1, 0)),
            mask: CollisionMask(.analyticTarget)
        ))

        #expect(hit.collider == capsule)
        #expect(hit.hit.distance == 8)
        #expect(hit.hit.normal == .init(-1, 0))
    }

    private func firstCollision(in world: CollisionWorld2D) -> Collision2D? {
        world.advance()
        var collision: Collision2D?
        world.forEachCollision {
            if collision == nil { collision = $0 }
        }
        return collision
    }
}
