import Swift

/// A rectangular render view into the game world.
///
/// `RenderView` stores the world-space area to render plus optional padding for
/// visible-frame calculations.
///
/// ```swift
/// let view = RenderView(
///     origin: camera.origin,
///     size: game.logicalResolution,
///     padding: EdgeInsets(16)
/// )
/// ```
public struct RenderView: Equatable, Sendable {
    /// World-space origin of the render view.
    public let origin: Vec2

    /// Logical render size.
    public let size: Vec2

    /// Insets applied when computing visible frame/bounds.
    public let padding: EdgeInsets

    /// Creates a render view.
    public init(
        origin: Vec2,
        size: Vec2,
        padding: EdgeInsets = .zero
    ) {
        self.origin = origin
        self.size = size
        self.padding = padding
    }

    /// World-space bounds of the full render view.
    public var bounds: Rect {
        Rect(origin: origin, size: size)
    }

    /// Origin used when rendering.
    public var renderOrigin: Vec2 {
        origin
    }

    /// Size used when rendering.
    public var renderSize: Vec2 {
        size
    }

    /// Local visible frame after padding.
    public var visibleFrame: Rect {
        Rect(
            x: padding.left,
            y: padding.top,
            width: max(size.x - padding.horizontal, 0),
            height: max(size.y - padding.vertical, 0)
        )
    }

    /// World-space visible bounds after padding.
    public var visibleBounds: Rect {
        Rect(
            origin: Vec2(
                x: origin.x + padding.left,
                y: origin.y + padding.top
            ),
            size: visibleFrame.size
        )
    }
}
