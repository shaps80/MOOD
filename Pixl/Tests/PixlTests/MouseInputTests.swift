import Pixl2D
import PixlPlatform
import Testing
@testable import Pixl

@Suite("Mouse input")
struct MouseInputTests {
    @Test
    func resolvesLogicalScreenLocationAndTranslation() {
        let mouse = MouseInput(source: Mouse())
        mouse.update(
            rawLocation: .init(600, 450),
            rawTranslation: .init(20, -10),
            presentationSize: .init(width: 1_200, height: 900),
            displayScale: 2
        )

        #expect(mouse.location(in: .screen) == .init(300, 225))
        #expect(mouse.translation(in: .screen) == .init(10, 5))
    }

    @Test
    func resolvesWorldLocationAndTranslationThroughCamera() {
        let mouse = MouseInput(source: Mouse())
        mouse.update(
            rawLocation: .init(1_200, 900),
            rawTranslation: .init(120, 90),
            presentationSize: .init(width: 1_200, height: 900),
            displayScale: 2
        )
        let camera = OrthographicCamera(
            center: .init(100, 50),
            halfHeight: 225
        )

        #expect(mouse.location(in: .world(camera)) == .init(400, 275))
        #expect(mouse.translation(in: .world(camera)) == .init(60, 45))
    }

    @Test
    func resolvesThroughAnyTwoDimensionalCameraProjection() {
        let mouse = MouseInput(source: Mouse())
        mouse.update(
            rawLocation: .init(1_200, 900),
            rawTranslation: .init(150, 112.5),
            presentationSize: .init(width: 1_200, height: 900),
            displayScale: 2
        )

        #expect(
            mouse.location(in: .world(AxisSwappedCamera()))
                == .init(8, 4)
        )
        #expect(
            mouse.translation(in: .world(AxisSwappedCamera()))
                == .init(2, 1)
        )
    }

    @Test
    func resolvesEventAndSampleCoordinates() {
        let mouse = MouseInput(source: Mouse())
        mouse.update(
            rawLocation: .zero,
            rawTranslation: .zero,
            presentationSize: .init(width: 1_200, height: 900),
            displayScale: 2
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

        #expect(mouse.location(in: .screen, for: buttonEvent) == .init(100, 100))
        #expect(mouse.location(in: .screen, for: sample) == .init(300, 225))
        #expect(mouse.translation(in: .screen, for: sample) == .init(10, 5))
    }

    @Test
    func invalidResolutionNeverStopsInput() {
        let mouse = MouseInput(source: Mouse())

        #expect(!mouse.location(in: .screen).isValid)
        #expect(mouse.translation(in: .screen) == .zero)

        mouse.update(
            rawLocation: .init(10, 20),
            rawTranslation: .init(3, 4),
            presentationSize: .init(width: 100, height: 100),
            displayScale: 1
        )

        #expect(!mouse.location(in: .world(SingularCamera())).isValid)
        #expect(mouse.translation(in: .world(SingularCamera())) == .zero)
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
