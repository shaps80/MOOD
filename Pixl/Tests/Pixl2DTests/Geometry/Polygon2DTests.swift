import Pixl2D
import Testing

@Suite
struct Polygon2DTests {
    @Test
    func normalizesClockwiseInputAndComputesBounds() {
        let polygon = Polygon2D(
            Vec2(0, 0),
            Vec2(0, 10),
            Vec2(20, 10),
            Vec2(20, 0)
        )

        #expect(Array(polygon) == [
            Vec2(20, 0),
            Vec2(20, 10),
            Vec2(0, 10),
            Vec2(0, 0),
        ])
        #expect(polygon.bounds == Rect(x: 0, y: 0, width: 20, height: 10))
    }

    @Test
    func removesClosingDuplicateConsecutiveDuplicatesAndCollinearVertices() {
        let polygon = Polygon2D([
            Vec2(0, 0),
            Vec2(5, 0),
            Vec2(10, 0),
            Vec2(10, 0),
            Vec2(10, 10),
            Vec2(0, 10),
            Vec2(0, 0),
        ])

        #expect(Array(polygon) == [
            Vec2(0, 0),
            Vec2(10, 0),
            Vec2(10, 10),
            Vec2(0, 10),
        ])
    }

    @Test
    func preservesConcaveBoundaries() {
        let polygon = Polygon2D(
            Vec2(0, 0),
            Vec2(10, 0),
            Vec2(5, 5),
            Vec2(10, 10),
            Vec2(0, 10)
        )

        #expect(polygon.count == 5)
        #expect(polygon[2] == Vec2(5, 5))
    }

    @Test
    func collectionsExposeBoundingRectWithoutAllocation() {
        let points = [Vec2(-5, 4), Vec2(10, -2), Vec2(3, 8)]

        #expect(points.boundingRect == Rect(x: -5, y: -2, width: 15, height: 10))
        #expect(![Vec2]().boundingRect.isValid)
    }

    @Test
    func segmentsContainPointsAndIntersect() {
        let horizontal = Segment(start: Vec2(0, 5), end: Vec2(10, 5))
        let vertical = Segment(start: Vec2(4, 0), end: Vec2(4, 10))

        #expect(horizontal.contains(Vec2(4, 5)))
        #expect(horizontal.contains(Vec2(0, 5)))
        #expect(!horizontal.contains(Vec2(11, 5)))
        #expect(!horizontal.contains(Vec2(4, 5.1)))
        #expect(horizontal.intersects(vertical))
    }
}
