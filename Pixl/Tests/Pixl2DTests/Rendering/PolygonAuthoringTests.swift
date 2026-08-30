import Pixl2D
import PixlGraphics
import Testing

@Suite
struct PolygonAuthoringTests {
    @Test
    func retainsGeometryAndPaint() {
        let geometry = Polygon2D(
            Vec2(-1, -1),
            Vec2(1, -1),
            Vec2(0, 1)
        )
        let polygon = Polygon(geometry, paint: .color(.cyan))

        #expect(polygon.geometry == geometry)
        #expect(polygon.paint == .color(.cyan))
        #expect(polygon.bounds == geometry.bounds)
    }

    @Test
    func collectionAndVariadicInitializersMatchPolygonGeometry() {
        let vertices = [
            Vec2(-1, -1),
            Vec2(1, -1),
            Vec2(0, 1),
        ]

        #expect(Polygon(vertices).geometry == Polygon2D(vertices))
        #expect(Polygon(vertices[0], vertices[1], vertices[2]).geometry == Polygon2D(vertices))
    }

    @Test
    func triangleConvenienceCreatesCenteredRightTriangle() {
        let polygon = Polygon(
            triangle: Size(width: 200, height: 80),
            paint: .color(.gray)
        )

        #expect(Array(polygon.geometry) == [
            Vec2(-100, -40),
            Vec2(100, -40),
            Vec2(100, 40),
        ])
        #expect(polygon.bounds == Rect(x: -100, y: -40, width: 200, height: 80))
    }
}
