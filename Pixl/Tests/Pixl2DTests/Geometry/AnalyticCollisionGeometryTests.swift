import Pixl2D
import Testing

@Suite("Analytic collision geometry")
struct AnalyticCollisionGeometryTests {
    @Test
    func circleRetainsLocalCentreRadiusAndBounds() {
        let circle = Circle2D(center: .init(4, 6), radius: 3)

        #expect(circle.center == .init(4, 6))
        #expect(circle.radius == 3)
        #expect(circle.bounds == Rect(x: 1, y: 3, width: 6, height: 6))
    }

    @Test
    func capsuleSizeCreatesCentredVerticalSegment() {
        let capsule = Capsule2D(
            center: .init(10, 20),
            size: .init(6, 14)
        )

        #expect(capsule.radius == 3)
        #expect(capsule.segment.start == .init(10, 16))
        #expect(capsule.segment.end == .init(10, 24))
        #expect(capsule.bounds == Rect(x: 7, y: 13, width: 6, height: 14))
    }

    @Test
    func angledCapsuleBoundsIncludeItsRadius() {
        let capsule = Capsule2D(
            segment: .init(start: .init(-2, 3), end: .init(4, -1)),
            radius: 2
        )

        #expect(capsule.bounds == Rect(x: -4, y: -3, width: 10, height: 8))
    }
}
