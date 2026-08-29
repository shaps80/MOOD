import Pixl2D
import PixlGraphics
import Testing

@Suite("Pixl2D geometry")
struct GeometryTests {
    @Test
    func spatialValuesUseCompactFloatStorage() {
        #expect(MemoryLayout<Vec2>.stride == 8)
        #expect(MemoryLayout<Rect>.stride == 16)
        #expect(MemoryLayout<Angle>.stride == 4)
        #expect(!Vec2.invalid.isValid)
    }

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

    @Test
    func cameraReportsVisibleWorldBounds() {
        let camera = OrthographicCamera(center: .init(2, -1), halfHeight: 2)

        #expect(
            camera.visibleBounds(aspectRatio: 2)
                == Rect(x: -2, y: -3, width: 8, height: 4)
        )
        #expect(
            camera.visibleBounds(in: .init(800, 400))
                == camera.visibleBounds(aspectRatio: 2)
        )
    }

    @Test
    func affineInverseTransformsPointsAndVectorsDifferently() throws {
        let transform = Transform2D(
            .init(100, 50),
            rotation: .pi / 2,
            scale: .init(2, 4)
        )
        let inverse = try #require(transform.inverted)

        #expect(
            inverse.transformed(point: transform.transformed(point: .init(3, 5)))
                == .init(3, 5)
        )
        #expect(
            inverse.transformed(vector: transform.transformed(vector: .init(3, 5)))
                == .init(3, 5)
        )
        #expect(transform.transformed(point: .zero) != transform.transformed(vector: .zero))
        #expect(Transform2D(scale: .init(0, 1)).inverted == nil)
    }
}
