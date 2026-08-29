import Pixl2D
import PixlPlatform
import Testing
@testable import Pixl

@Suite("Mouse input")
struct MouseInputTests {
    @Test
    func resolvesLogicalScreenLocationAndTranslation() throws {
        let mouse = MouseInput(source: Mouse())
        mouse.update(
            rawLocation: .init(600, 450),
            rawTranslation: .init(20, -10)
        )
        let screen = try resolved(.screen)

        #expect(screen.location(for: mouse) == .init(300, 225))
        #expect(screen.translation(for: mouse) == .init(10, 5))
    }

    @Test
    func resolvesWorldLocationAndTranslationThroughCamera() throws {
        let mouse = MouseInput(source: Mouse())
        mouse.update(
            rawLocation: .init(1_200, 900),
            rawTranslation: .init(120, 90)
        )
        let camera = OrthographicCamera(
            center: .init(100, 50),
            halfHeight: 225
        )
        let world = try resolved(.world(camera))

        #expect(world.location(for: mouse) == .init(400, 275))
        #expect(world.translation(for: mouse) == .init(60, 45))
    }

    @Test
    func resolvesThroughAnyTwoDimensionalCameraProjection() throws {
        let mouse = MouseInput(source: Mouse())
        mouse.update(
            rawLocation: .init(1_200, 900),
            rawTranslation: .init(150, 112.5)
        )
        let world = try resolved(.world(AxisSwappedCamera()))

        #expect(
            world.location(for: mouse) == .init(8, 4)
        )
        #expect(
            world.translation(for: mouse) == .init(2, 1)
        )
    }

    @Test
    func resolvesEventAndSampleCoordinates() throws {
        let mouse = MouseInput(source: Mouse())
        mouse.update(
            rawLocation: .zero,
            rawTranslation: .zero
        )
        let buttonEvent = Mouse.Button.Event(
            timestamp: 1,
            button: .primary,
            phase: .down,
            rawLocation: .init(200, 700)
        )
        let sample = Mouse.Sample(
            timestamp: 2,
            rawLocation: .init(600, 450),
            rawTranslation: .init(20, -10)
        )
        let screen = try resolved(.screen)

        #expect(screen.location(for: buttonEvent) == .init(100, 100))
        #expect(screen.location(for: sample) == .init(300, 225))
        #expect(screen.translation(for: sample) == .init(10, 5))
    }

    @Test
    func resolvesObjectLocalCoordinatesOnce() throws {
        let mouse = MouseInput(source: Mouse())
        mouse.update(
            rawLocation: .init(800, 568),
            rawTranslation: .init(-9, 18)
        )
        let world = try resolved(.world(OrthographicCamera(halfHeight: 225)))
        let transform = Transform2D(.init(100, 50), rotation: .pi / 2)
        let local = world.coordinates(relativeTo: transform)

        #expect(local.location(for: mouse) == .init(9, 0))
        let translation = local.translation(for: mouse)
        #expect(abs(translation.x - 9) < 0.000_01)
        #expect(abs(translation.y - 4.5) < 0.000_01)
    }

    @Test
    func invalidResolutionNeverStopsInput() throws {
        let mouse = MouseInput(source: Mouse())
        let unavailable = ResolvedCoordinateSpace()

        #expect(!unavailable.location(for: mouse).isValid)
        #expect(unavailable.translation(for: mouse) == .zero)

        mouse.update(
            rawLocation: .init(10, 20),
            rawTranslation: .init(3, 4)
        )
        let singular = try resolved(
            .world(SingularCamera()),
            presentationSize: .init(width: 100, height: 100),
            displayScale: 1
        )

        #expect(!singular.location(for: mouse).isValid)
        #expect(singular.translation(for: mouse) == .zero)

        let world = try resolved(.world(OrthographicCamera(halfHeight: 50)))
        let local = world.coordinates(
            relativeTo: Transform2D(scale: .init(0, 1))
        )
        #expect(!local.isValid)
        #expect(!local.location(for: mouse).isValid)
        #expect(local.translation(for: mouse) == .zero)
    }

    private func resolved(
        _ coordinateSpace: CoordinateSpace,
        presentationSize: TextureSize = .init(width: 1_200, height: 900),
        displayScale: Float = 2
    ) throws -> ResolvedCoordinateSpace {
        let converter = try #require(CoordinateConverter(
            presentationSize: presentationSize,
            displayScale: displayScale
        ))
        return converter.resolved(in: coordinateSpace)
    }
}

private struct AxisSwappedCamera: Camera2D {
    func projection(in presentationSize: Vec2) -> Transform2D {
        .init(
            x: .init(0, 0.125, 0),
            y: .init(0.25, 0, 0),
            translation: .init(0, 0, 1)
        )
    }
}

private struct SingularCamera: Camera2D {
    func projection(in presentationSize: Vec2) -> Transform2D {
        .init(scale: .init(0, 1))
    }
}
