import Pixl2D
import PixlPlatform

public extension ResolvedCoordinateSpace {
    /// Returns the mouse's current location in this coordinate space.
    func location(for mouse: MouseInput) -> Vec2 {
        location(forRawLocation: mouse.rawLocation)
    }

    /// Returns the mouse's current movement in this coordinate space.
    func translation(for mouse: MouseInput) -> Vec2 {
        translation(forRawTranslation: mouse.rawTranslation)
    }

    /// Returns a motion sample's location in this coordinate space.
    func location(for sample: PixlPlatform.Mouse.Sample) -> Vec2 {
        location(forRawLocation: sample.rawLocation)
    }

    /// Returns a motion sample's movement in this coordinate space.
    func translation(for sample: PixlPlatform.Mouse.Sample) -> Vec2 {
        translation(forRawTranslation: sample.rawTranslation)
    }

    /// Returns a button event's location in this coordinate space.
    func location(for event: PixlPlatform.Mouse.Button.Event) -> Vec2 {
        location(forRawLocation: event.rawLocation)
    }

    /// Returns a scroll event's location in this coordinate space.
    func location(for event: PixlPlatform.Mouse.ScrollEvent) -> Vec2 {
        location(forRawLocation: event.rawLocation)
    }
}
