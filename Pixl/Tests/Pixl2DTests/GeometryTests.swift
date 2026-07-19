import Pixl2D
import Testing

@Suite("Pixl2D geometry")
struct GeometryTests {
    @Test
    func primitivesArePlainGeometryValues() {
        let triangle = Triangle()
        let quad = Quad()

        #expect(triangle.a == .init(0, 0.5))
        #expect(triangle.b == .init(-0.5, -0.5))
        #expect(triangle.c == .init(0.5, -0.5))
        #expect(quad.topLeft == .init(-0.5, 0.5))
        #expect(quad.bottomLeft == .init(-0.5, -0.5))
        #expect(quad.bottomRight == .init(0.5, -0.5))
        #expect(quad.topRight == .init(0.5, 0.5))
    }

    @Test
    func cameraProjectsFromSizeOrAspectRatio() {
        let camera = OrthographicCamera(center: .init(2, -1), halfHeight: 2)
        let fromSize = camera.projection(in: .init(800, 400))
        let fromAspectRatio = camera.projection(aspectRatio: 2)

        #expect(fromSize.x == fromAspectRatio.x)
        #expect(fromSize.y == fromAspectRatio.y)
        #expect(fromSize.translation == fromAspectRatio.translation)
    }
}
