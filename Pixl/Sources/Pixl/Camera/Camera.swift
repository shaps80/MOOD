import Swift

/// The resolved viewport in world space.
///
/// `Camera` does not know why it is looking at a place. That decision belongs
/// to `CameraRig`, which combines anchor, tracking, constraints, and a
/// presentation transform. Renderers consume the final origin plus that
/// transform.
///
/// Coordinate model:
///
/// ```text
/// world space
/// +--------------------------------------------------+
/// |                                                  |
/// |     camera.origin                                |
/// |          v                                       |
/// |          +------------------------------+        |
/// |          |                              |        |
/// |          |      visibleBounds           |        |
/// |          |                              |        |
/// |          +------------------------------+        |
/// |                 camera.viewportSize              |
/// |                                                  |
/// +--------------------------------------------------+
/// ```
///
/// Renderer contract:
///
/// ```text
/// screenPosition = cameraTransform(worldPosition - camera.origin)
/// ```
public struct Camera: Equatable, Sendable {
    /// The top-left world coordinate visible through the viewport.
    public internal(set) var origin: Vec2

    /// The size of the visible world-space viewport.
    public let viewportSize: Vec2

    /// Creates a resolved camera viewport.
    ///
    /// - Parameters:
    ///   - origin: The top-left world coordinate visible through the viewport.
    ///   - viewportSize: The visible world-space size.
    public init(origin: Vec2 = .zero, viewportSize: Vec2) {
        self.origin = origin
        self.viewportSize = viewportSize
    }

    /// The current visible world-space rectangle.
    public var visibleBounds: Rect {
        Rect(origin: origin, size: viewportSize)
    }
}
