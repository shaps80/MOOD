import Pixl2D
import PixlPlatform

/// Mouse state resolved against the current presentation frame.
public final class MouseInput {
    private let source: PixlPlatform.Mouse
    private var rawLocation = Vec2.zero
    private var rawTranslation = Vec2.zero
    private var presentationSize = TextureSize(width: 0, height: 0)
    private var displayScale: Float = 1

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

    /// Returns the current pointer location in the requested coordinate space.
    public func location(in coordinateSpace: CoordinateSpace) -> Vec2 {
        location(rawLocation, in: coordinateSpace)
    }

    /// Returns a motion sample's pointer location in the requested coordinate space.
    public func location(
        in coordinateSpace: CoordinateSpace,
        for sample: PixlPlatform.Mouse.Sample
    ) -> Vec2 {
        location(sample.rawLocation, in: coordinateSpace)
    }

    /// Returns a button event's pointer location in the requested coordinate space.
    public func location(
        in coordinateSpace: CoordinateSpace,
        for event: PixlPlatform.Mouse.Button.Event
    ) -> Vec2 {
        location(event.rawLocation, in: coordinateSpace)
    }

    /// Returns a scroll event's pointer location in the requested coordinate space.
    public func location(
        in coordinateSpace: CoordinateSpace,
        for event: PixlPlatform.Mouse.ScrollEvent
    ) -> Vec2 {
        location(event.rawLocation, in: coordinateSpace)
    }

    /// Returns this frame's pointer movement in the requested coordinate space.
    public func translation(in coordinateSpace: CoordinateSpace) -> Vec2 {
        translation(rawTranslation, in: coordinateSpace)
    }

    /// Returns a motion sample's pointer movement in the requested coordinate space.
    public func translation(
        in coordinateSpace: CoordinateSpace,
        for sample: PixlPlatform.Mouse.Sample
    ) -> Vec2 {
        translation(sample.rawTranslation, in: coordinateSpace)
    }

    private func location(_ rawLocation: Vec2, in coordinateSpace: CoordinateSpace) -> Vec2 {
        let size = resolvedPresentationSize

        switch coordinateSpace {
        case .screen:
            return .init(
                rawLocation.x / displayScale,
                (size.y - rawLocation.y) / displayScale
            )

        case .world(let camera):
            let clip = Vec2(
                rawLocation.x / size.x * 2 - 1,
                rawLocation.y / size.y * 2 - 1
            )
            let halfWidth = camera.halfHeight * size.x / size.y
            return .init(
                camera.center.x + clip.x * halfWidth,
                camera.center.y + clip.y * camera.halfHeight
            )
        }
    }

    private func translation(
        _ rawTranslation: Vec2,
        in coordinateSpace: CoordinateSpace
    ) -> Vec2 {
        let size = resolvedPresentationSize

        switch coordinateSpace {
        case .screen:
            return .init(
                rawTranslation.x / displayScale,
                -rawTranslation.y / displayScale
            )

        case .world(let camera):
            let halfWidth = camera.halfHeight * size.x / size.y
            return .init(
                rawTranslation.x * (halfWidth * 2 / size.x),
                rawTranslation.y * (camera.halfHeight * 2 / size.y)
            )
        }
    }

    package func update(
        rawLocation: Vec2,
        rawTranslation: Vec2,
        presentationSize: TextureSize,
        displayScale: Float
    ) {
        precondition(
            presentationSize.width > 0 && presentationSize.height > 0,
            "Presentation dimensions must be greater than zero"
        )
        precondition(
            displayScale.isFinite && displayScale > 0,
            "Display scale must be finite and greater than zero"
        )
        self.rawLocation = rawLocation
        self.rawTranslation = rawTranslation
        self.presentationSize = presentationSize
        self.displayScale = displayScale
    }

    private var resolvedPresentationSize: Vec2 {
        precondition(
            presentationSize.width > 0 && presentationSize.height > 0,
            "Mouse coordinates are unavailable before the first presentation frame"
        )
        return .init(
            Float(presentationSize.width),
            Float(presentationSize.height)
        )
    }
}
