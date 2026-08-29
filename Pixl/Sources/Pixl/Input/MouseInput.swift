import Pixl2D
import PixlPlatform

/// Game-facing physical mouse state.
public final class MouseInput {
    private let source: PixlPlatform.Mouse
    package var rawLocation = Vec2.zero
    package var rawTranslation = Vec2.zero

    package init(source: PixlPlatform.Mouse) {
        self.source = source
    }

    /// Whether the presentation currently has mouse focus.
    public var isFocused: Bool { source.isFocused }
    /// Ordered high-frequency motion samples published for this frame.
    public var samples: PixlPlatform.Mouse.Samples { source.samples }
    /// Ordered button transitions published for this frame.
    public var buttonEvents: PixlPlatform.Mouse.ButtonEvents { source.buttonEvents }
    /// Ordered scrolling events published for this frame.
    public var scrollEvents: PixlPlatform.Mouse.ScrollEvents { source.scrollEvents }

    /// Returns whether a physical mouse button is currently held.
    public func isPressed(_ button: PixlPlatform.Mouse.Button) -> Bool {
        source.isPressed(button)
    }

    /// Returns whether a physical mouse button was pressed this frame.
    public func wasPressed(_ button: PixlPlatform.Mouse.Button) -> Bool {
        source.wasPressed(button)
    }

    /// Returns whether a physical mouse button was released this frame.
    public func wasReleased(_ button: PixlPlatform.Mouse.Button) -> Bool {
        source.wasReleased(button)
    }

    /// Returns one matching button transition from this frame.
    public func event(
        _ button: PixlPlatform.Mouse.Button,
        phase: PixlPlatform.Mouse.Button.Phase
    ) -> PixlPlatform.Mouse.Button.Event? {
        source.event(button, phase: phase)
    }

    package func update(
        rawLocation: Vec2,
        rawTranslation: Vec2
    ) {
        self.rawLocation = rawLocation
        self.rawTranslation = rawTranslation
    }
}
