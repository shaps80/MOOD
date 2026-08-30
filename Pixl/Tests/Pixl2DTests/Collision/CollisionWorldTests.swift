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
    func advanceSynchronizesCorrectedSourceBoundsReturnedByCallback() {
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
        let correctedBounds = Rect(x: -2, y: 0, width: 10, height: 10)

        world.advance { collision in
            #expect(collision.source.collider == player)
            return Transform2D(correctedBounds.center)
        }

        #expect(world.bounds(for: player) == correctedBounds)
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

    @Test
    func rectangleContactsTriangleUsingItsSlopeNormal() {
        let world = CollisionWorld2D()
        let slope = Polygon2D(
            Vec2(-10, -10),
            Vec2(10, -10),
            Vec2(10, 10)
        )
        _ = world.insert(
            slope,
            mode: .static,
            layer: .world,
            mask: .none
        )
        let player = world.insert(
            bounds: Rect(x: -1, y: 0, width: 2, height: 2),
            mode: .dynamic,
            layer: .player,
            mask: CollisionMask(.world)
        )

        world.advance()
        let report = Self.reports(from: world).first
        let expected = Float(0.5).squareRoot()

        #expect(report?.source.collider == player)
        #expect(abs((report?.contact?.normal.x ?? 0) - expected) < 0.0001)
        #expect(abs((report?.contact?.normal.y ?? 0) + expected) < 0.0001)
        #expect(abs((report?.contact?.depth ?? 0) - expected) < 0.0001)
    }

    @Test
    func decompositionEdgeNeverBecomesRectangleContactNormal() {
        let world = CollisionWorld2D()
        let polygon = Polygon2D(
            Vec2(0, 0),
            Vec2(10, 0),
            Vec2(10, 10),
            Vec2(0, 10)
        )
        _ = world.insert(
            polygon,
            mode: .static,
            layer: .world,
            mask: .none
        )
        _ = world.insert(
            bounds: Rect(x: 4, y: 4, width: 2, height: 2),
            mode: .dynamic,
            layer: .player,
            mask: CollisionMask(.world)
        )

        world.advance()
        let normal = Self.reports(from: world).first?.contact?.normal

        #expect(normal != nil)
        #expect(normal?.x == 0 || normal?.y == 0)
    }

    @Test
    func concavePolygonRejectsQueryInsideOnlyItsAABB() {
        let world = CollisionWorld2D()
        let concave = Polygon2D(
            Vec2(0, 0),
            Vec2(10, 0),
            Vec2(10, 4),
            Vec2(4, 4),
            Vec2(4, 10),
            Vec2(0, 10)
        )
        _ = world.insert(
            concave,
            mode: .static,
            layer: .world,
            mask: .none
        )
        var found = false

        world.query(
            overlapping: Rect(x: 6, y: 6, width: 2, height: 2),
            mask: CollisionMask(.world)
        ) { _ in
            found = true
            return false
        }

        #expect(!found)
    }

    @Test
    func polygonRayCastUsesBoundaryRatherThanAABB() {
        let world = CollisionWorld2D()
        let slope = Polygon2D(
            Vec2(0, 0),
            Vec2(10, 0),
            Vec2(10, 10)
        )
        let collider = world.insert(
            slope,
            mode: .static,
            layer: .world,
            mask: .none
        )

        let hit = world.rayCast(
            Ray2D(origin: Vec2(-5, 5), direction: Vec2(1, 0)),
            mask: CollisionMask(.world)
        )
        let expected = Float(0.5).squareRoot()

        #expect(hit?.collider == collider)
        #expect(hit?.hit.distance == 10)
        #expect(abs((hit?.hit.normal.x ?? 0) + expected) < 0.0001)
        #expect(abs((hit?.hit.normal.y ?? 0) - expected) < 0.0001)
    }

    @Test
    func polygonTransformUpdatesCoalesceBeforeSynchronization() {
        let world = CollisionWorld2D()
        let polygon = Polygon2D(
            Vec2(0, 0),
            Vec2(10, 0),
            Vec2(10, 10)
        )
        let collider = world.insert(
            polygon,
            mode: .static,
            layer: .world,
            mask: .none
        )

        world.update(collider, transform: Transform2D(Vec2(50, 0)))
        world.update(collider, transform: Transform2D(Vec2(100, 0)))

        #expect(
            world.bounds(for: collider)
                == Rect(x: 100, y: 0, width: 10, height: 10)
        )
        let hit = world.rayCast(
            Ray2D(origin: Vec2(95, 5), direction: Vec2(1, 0)),
            mask: CollisionMask(.world)
        )
        #expect(hit?.hit.distance == 10)
    }

    @Test
    func polygonCanBeTheDirectedDynamicSource() {
        let world = CollisionWorld2D()
        let triangle = Polygon2D(
            Vec2(0, 0),
            Vec2(10, 0),
            Vec2(10, 10)
        )
        let source = world.insert(
            triangle,
            mode: .dynamic,
            layer: .player,
            mask: CollisionMask(.world)
        )
        _ = world.insert(
            bounds: Rect(x: 8, y: 0, width: 4, height: 4),
            mode: .static,
            layer: .world,
            mask: .none
        )

        world.advance()
        let report = Self.reports(from: world).first

        #expect(report?.source.collider == source)
        #expect(report?.contact != nil)
    }

    @Test
    func polygonContactsPolygonThroughConvexPieces() {
        let world = CollisionWorld2D()
        let triangle = Polygon2D(
            Vec2(0, 0),
            Vec2(10, 0),
            Vec2(10, 10)
        )
        let source = world.insert(
            triangle,
            mode: .dynamic,
            layer: .player,
            mask: CollisionMask(.world)
        )
        let target = world.insert(
            triangle,
            transform: Transform2D(Vec2(8, 0)),
            mode: .static,
            layer: .world,
            mask: .none
        )

        world.advance()
        let report = Self.reports(from: world).first

        #expect(report?.source.collider == source)
        #expect(report?.target.collider == target)
        #expect(report?.contact != nil)
    }

    @Test
    func removingDirtyPolygonDoesNotSynchronizeReusedColliderSlot() {
        let world = CollisionWorld2D()
        let triangle = Polygon2D(
            Vec2(0, 0),
            Vec2(10, 0),
            Vec2(10, 10)
        )
        let removed = world.insert(
            triangle,
            mode: .static,
            layer: .world,
            mask: .none
        )
        world.update(removed, transform: Transform2D(Vec2(100, 0)))
        world.remove(removed)

        let replacementBounds = Rect(x: 20, y: 30, width: 4, height: 5)
        let replacement = world.insert(
            bounds: replacementBounds,
            mode: .static,
            layer: .world,
            mask: .none
        )
        world.advance()

        #expect(world.bounds(for: replacement) == replacementBounds)
    }
}

private extension CollisionWorldTests {
    static func reports(from world: CollisionWorld2D) -> [Collision2D] {
        var values: [Collision2D] = []
        world.forEachCollision { values.append($0) }
        return values
    }
}
