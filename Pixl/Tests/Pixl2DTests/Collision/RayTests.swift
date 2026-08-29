import Testing
import Pixl2D

@Suite
struct RayTests {
    @Test
    func rayNormalizesDirection() {
        let ray = Ray2D(
            origin: .init(10, 20),
            direction: .init(3, 4)
        )

        #expect(ray.origin == .init(10, 20))
        #expect(abs(ray.normalizedDirection.x - 0.6) < 0.000_001)
        #expect(abs(ray.normalizedDirection.y - 0.8) < 0.000_001)
    }

    @Test
    func zeroDirectionRemainsZero() {
        let ray = Ray2D(
            origin: .init(10, 20),
            direction: .zero
        )

        #expect(ray.normalizedDirection == .zero)
    }

    @Test
    func returnsPointAtDistance() {
        let ray = Ray2D(
            origin: .init(10, 20),
            direction: .init(3, 4)
        )

        #expect(ray.point(at: 5) == .init(13, 24))
    }

    @Test
    func rayMissingRectangleReturnsNil() {
        let rect = Rect(x: 10, y: 10, width: 10, height: 10)
        let ray = Ray2D(
            origin: .zero,
            direction: .init(1, 0)
        )

        #expect(rect.intersection(with: ray) == nil)
    }

    @Test
    func rayTowardsRectangleReturnsHit() {
        let rect = Rect(x: 10, y: -5, width: 10, height: 10)
        let ray = Ray2D(
            origin: .zero,
            direction: .init(1, 0)
        )

        #expect(rect.intersection(with: ray) != nil)
    }

    @Test
    func rightMovingRayHitsLeftEdge() {
        let rect = Rect(x: 10, y: -5, width: 10, height: 10)
        let ray = Ray2D(
            origin: .zero,
            direction: .init(1, 0)
        )

        let hit = rect.intersection(with: ray)

        #expect(hit?.distance == 10)
        #expect(hit?.normal == .init(-1, 0))
        #expect(ray.point(at: hit?.distance ?? 0) == .init(10, 0))
    }

    @Test
    func leftMovingRayHitsRightEdge() {
        let rect = Rect(x: -20, y: -5, width: 10, height: 10)
        let ray = Ray2D(
            origin: .zero,
            direction: .init(-1, 0)
        )

        let hit = rect.intersection(with: ray)

        #expect(hit?.distance == 10)
        #expect(hit?.normal == .init(1, 0))
    }

    @Test
    func upwardMovingRayHitsBottomEdge() {
        let rect = Rect(x: -5, y: 10, width: 10, height: 10)
        let ray = Ray2D(origin: .zero, direction: .init(0, 1))

        let hit = rect.intersection(with: ray)

        #expect(hit?.distance == 10)
        #expect(hit?.normal == .init(0, -1))
    }

    @Test
    func downwardMovingRayHitsTopEdge() {
        let rect = Rect(x: -5, y: -20, width: 10, height: 10)
        let ray = Ray2D(origin: .zero, direction: .init(0, -1))

        let hit = rect.intersection(with: ray)

        #expect(hit?.distance == 10)
        #expect(hit?.normal == .init(0, 1))
    }

    @Test
    func diagonalRayUsesFirstEdgeReached() {
        let rect = Rect(x: 5, y: 10, width: 10, height: 10)
        let ray = Ray2D(origin: .zero, direction: .init(1, 1))

        let hit = rect.intersection(with: ray)

        #expect(abs((hit?.distance ?? 0) - Float(200).squareRoot()) < 0.000_001)
        #expect(hit?.normal == .init(0, -1))
        let point = ray.point(at: hit?.distance ?? 0)
        #expect(abs(point.x - 10) < 0.000_001)
        #expect(abs(point.y - 10) < 0.000_001)
    }

    @Test
    func intersectionBehindRayReturnsNil() {
        let rect = Rect(x: -20, y: -5, width: 10, height: 10)
        let ray = Ray2D(origin: .zero, direction: .init(1, 0))

        #expect(rect.intersection(with: ray) == nil)
    }

    @Test
    func parallelRayOutsideRectangleReturnsNil() {
        let rect = Rect(x: 10, y: 10, width: 10, height: 10)
        let ray = Ray2D(origin: .zero, direction: .init(0, 1))

        #expect(rect.intersection(with: ray) == nil)
    }

    @Test
    func zeroDirectionReturnsNil() {
        let rect = Rect(x: -5, y: -5, width: 10, height: 10)
        let ray = Ray2D(origin: .zero, direction: .zero)

        #expect(rect.intersection(with: ray) == nil)
    }

    @Test
    func rayStartingInsideRectangleHitsExitEdge() {
        let rect = Rect(x: -5, y: -5, width: 10, height: 10)
        let ray = Ray2D(origin: .zero, direction: .init(1, 0))

        let hit = rect.intersection(with: ray)

        #expect(hit?.distance == 5)
        #expect(hit?.normal == .init(1, 0))
    }

    @Test
    func zeroVectorNormalizesToZero() {
        #expect(Vec2.zero.normalized == .zero)
    }
}
