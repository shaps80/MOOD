import Testing
import Pixl2D

private extension CollisionLayer {
    static let world: Self = 0
    static let player: Self = 1
    static let enemy: Self = 2
}

@Suite
struct CollisionWorldTests {
    @Test
    func gameOwnsColliderLifetimeThroughOpaqueID() {
        let world = CollisionWorld2D()
        let bounds = Rect(x: 10, y: 20, width: 30, height: 40)
        let player = world.insert(
            bounds: bounds,
            mode: .dynamic,
            layer: .player,
            mask: CollisionMask(.world, .enemy)
        )

        #expect(world.count == 1)
        #expect(world.bounds(for: player) == bounds)

        world.remove(player)

        #expect(world.count == 0)
        #expect(world.bounds(for: player) == nil)
    }

    @Test
    func advanceReportsOneWayBeganCollisionToInterestedSource() {
        let world = CollisionWorld2D()
        let wall = world.insert(
            bounds: Rect(x: 8, y: 0, width: 10, height: 10),
            mode: .static,
            layer: .world,
            mask: .none
        )
        let player = world.insert(
            bounds: Rect(x: 0, y: 0, width: 10, height: 10),
            mode: .dynamic,
            layer: .player,
            mask: CollisionMask(.world)
        )
        var reports: [Collision2D] = []

        world.advance()
        world.forEachCollision { reports.append($0) }

        #expect(reports.count == 1)
        #expect(reports.first?.source.collider == player)
        #expect(reports.first?.target.collider == wall)
        #expect(reports.first?.phase == .began)
        #expect(reports.first?.contact?.depth == 2)
    }

    @Test
    func persistentCollisionAdvancesThroughChangedAndEndedPhases() {
        let world = CollisionWorld2D()
        _ = world.insert(
            bounds: Rect(x: 8, y: 0, width: 10, height: 10),
            mode: .static,
            layer: .world,
            mask: .none
        )
        let player = world.insert(
            bounds: Rect(x: 0, y: 0, width: 10, height: 10),
            mode: .dynamic,
            layer: .player,
            mask: CollisionMask(.world)
        )

        world.advance()
        #expect(Self.reports(from: world).first?.phase == .began)

        world.advance()
        #expect(Self.reports(from: world).first?.phase == .changed)

        world.update(
            player,
            bounds: Rect(x: -20, y: 0, width: 10, height: 10)
        )
        world.advance()
        let ended = Self.reports(from: world)
        #expect(ended.count == 1)
        #expect(ended.first?.phase == .ended)
        #expect(ended.first?.contact == nil)
    }

    @Test
    func reciprocalInterestProducesTwoDirectedReportsFromOnePair() {
        let world = CollisionWorld2D()
        let player = world.insert(
            bounds: Rect(x: 0, y: 0, width: 10, height: 10),
            mode: .dynamic,
            layer: .player,
            mask: CollisionMask(.enemy)
        )
        let enemy = world.insert(
            bounds: Rect(x: 8, y: 0, width: 10, height: 10),
            mode: .dynamic,
            layer: .enemy,
            mask: CollisionMask(.player)
        )

        world.advance()
        let reports = Self.reports(from: world)
        let playerReport = reports.first { $0.source.collider == player }
        let enemyReport = reports.first { $0.source.collider == enemy }

        #expect(reports.count == 2)
        #expect(playerReport?.target.collider == enemy)
        #expect(enemyReport?.target.collider == player)
        #expect(playerReport?.contact?.normal == Vec2(1, 0))
        #expect(enemyReport?.contact?.normal == Vec2(-1, 0))
    }

    @Test
    func staticStaticPairsNeverProduceReports() {
        let world = CollisionWorld2D()
        _ = world.insert(
            bounds: Rect(x: 0, y: 0, width: 10, height: 10),
            mode: .static,
            layer: .world,
            mask: CollisionMask(.enemy)
        )
        _ = world.insert(
            bounds: Rect(x: 5, y: 0, width: 10, height: 10),
            mode: .static,
            layer: .enemy,
            mask: CollisionMask(.world)
        )

        world.advance()

        #expect(Self.reports(from: world).isEmpty)
    }

    @Test
    func overlapQueryUsesExactBoundsAndTargetLayerMask() {
        let world = CollisionWorld2D(broadMargin: 20)
        let player = world.insert(
            bounds: Rect(x: 5, y: 5, width: 5, height: 5),
            mode: .dynamic,
            layer: .player,
            mask: .none
        )
        _ = world.insert(
            bounds: Rect(x: 15, y: 15, width: 5, height: 5),
            mode: .static,
            layer: .enemy,
            mask: .none
        )
        var found: [ColliderID] = []

        world.query(
            overlapping: Rect(x: 0, y: 0, width: 10, height: 10),
            mask: CollisionMask(.player)
        ) { collider in
            found.append(collider)
            return true
        }

        #expect(found == [player])
    }

    @Test
    func rayCastReturnsNearestExactHitMatchingTargetLayerMask() {
        let world = CollisionWorld2D(broadMargin: 20)
        _ = world.insert(
            bounds: Rect(x: 10, y: 10, width: 5, height: 5),
            mode: .static,
            layer: .enemy,
            mask: .none
        )
        let player = world.insert(
            bounds: Rect(x: 20, y: -5, width: 5, height: 10),
            mode: .dynamic,
            layer: .player,
            mask: .none
        )

        let hit = world.rayCast(
            Ray2D(origin: .zero, direction: .init(1, 0)),
            mask: CollisionMask(.player)
        )

        #expect(hit?.collider == player)
        #expect(hit?.hit.distance == 20)
    }

    @Test
    func removingOverlappingColliderProducesEndedReport() {
        let world = CollisionWorld2D()
        let wall = world.insert(
            bounds: Rect(x: 8, y: 0, width: 10, height: 10),
            mode: .static,
            layer: .world,
            mask: .none
        )
        let player = world.insert(
            bounds: Rect(x: 0, y: 0, width: 10, height: 10),
            mode: .dynamic,
            layer: .player,
            mask: CollisionMask(.world)
        )
        world.advance()

        world.remove(wall)
        world.advance()
        let report = Self.reports(from: world).first

        #expect(report?.source.collider == player)
        #expect(report?.target.collider == wall)
        #expect(report?.phase == .ended)
    }

    @Test
    func reportStorageGrowsAndPreservesEveryUniqueDirectedPair() {
        let world = CollisionWorld2D()
        let colliderCount = 24
        for _ in 0..<colliderCount {
            _ = world.insert(
                bounds: Rect(x: 0, y: 0, width: 10, height: 10),
                mode: .dynamic,
                layer: .player,
                mask: CollisionMask(.player)
            )
        }

        world.advance()
        let expected = colliderCount * (colliderCount - 1)
        #expect(Self.reports(from: world).count == expected)

        world.advance()
        let changed = Self.reports(from: world)
        #expect(changed.count == expected)
        #expect(changed.allSatisfy { $0.phase == .changed })
    }

    @Test
    func removingDynamicColliderKeepsDenseDynamicTraversalValid() {
        let world = CollisionWorld2D()
        let first = world.insert(
            bounds: Rect(x: 0, y: 0, width: 10, height: 10),
            mode: .dynamic,
            layer: .player,
            mask: CollisionMask(.player)
        )
        let removed = world.insert(
            bounds: Rect(x: 0, y: 0, width: 10, height: 10),
            mode: .dynamic,
            layer: .player,
            mask: CollisionMask(.player)
        )
        let last = world.insert(
            bounds: Rect(x: 0, y: 0, width: 10, height: 10),
            mode: .dynamic,
            layer: .player,
            mask: CollisionMask(.player)
        )

        world.remove(removed)
        world.advance()
        let reports = Self.reports(from: world)

        #expect(reports.count == 2)
        #expect(reports.contains { $0.source.collider == first && $0.target.collider == last })
        #expect(reports.contains { $0.source.collider == last && $0.target.collider == first })
    }
}

private extension CollisionWorldTests {
    static func reports(from world: CollisionWorld2D) -> [Collision2D] {
        var values: [Collision2D] = []
        world.forEachCollision { values.append($0) }
        return values
    }
}
