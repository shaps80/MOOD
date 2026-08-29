import Pixl2D
import PixlPlatform
import Testing
@testable import Pixl

@Suite("Coordinate conversion")
struct CoordinateConverterTests {
    @Test
    func convertsPointsBetweenWorldAndLogicalScreen() throws {
        let converter = try #require(CoordinateConverter(
            presentationSize: .init(width: 1_200, height: 900),
            displayScale: 2
        ))
        let camera = OrthographicCamera(
            center: .init(100, 50),
            halfHeight: 225
        )

        #expect(
            converter.convert(
                .init(100, 50),
                from: .world(camera),
                to: .screen
            ) == .init(300, 225)
        )
        let world = converter.convert(
            .init(300, 225),
            from: .screen,
            to: .world(camera)
        )
        #expect(abs(world.x - 100) < 0.001)
        #expect(abs(world.y - 50) < 0.001)
    }

    @Test
    func convertsBoundsToTheirDestinationAxisAlignedBounds() throws {
        let converter = try #require(CoordinateConverter(
            presentationSize: .init(width: 1_200, height: 900),
            displayScale: 2
        ))
        let camera = OrthographicCamera(
            center: .init(100, 50),
            halfHeight: 225
        )

        let bounds = converter.convert(
            .init(center: .init(100, 50), size: .init(200, 100)),
            from: .world(camera),
            to: .screen
        )
        #expect(abs(bounds.origin.x - 200) < 0.001)
        #expect(abs(bounds.origin.y - 175) < 0.001)
        #expect(abs(bounds.size.x - 200) < 0.001)
        #expect(abs(bounds.size.y - 100) < 0.001)
    }

    @Test
    func invalidProjectionProducesInvalidValues() throws {
        let converter = try #require(CoordinateConverter(
            presentationSize: .init(width: 100, height: 100),
            displayScale: 1
        ))

        #expect(!converter.convert(
            .zero,
            from: .screen,
            to: .world(SingularConversionCamera())
        ).isValid)
        #expect(!converter.convert(
            Rect.zero,
            from: .screen,
            to: .world(SingularConversionCamera())
        ).isValid)
    }
}

private struct SingularConversionCamera: Camera2D {
    func projection(in presentationSize: Vec2) -> Transform2D {
        .init(scale: .init(0, 1))
    }
}
