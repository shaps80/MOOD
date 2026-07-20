import Swift

/// Screen-space coordinates relative to the current camera viewport.
///
/// Screen coordinates use a top-left origin at the visible viewport's origin.
/// Pixl resolves them by adding the camera/render-view origin. Spawn positions
/// place the spawned entity's top-left at the supplied screen point.
///
/// ```swift
/// context.spawn(Bullet.self, at: Vec2(x: 80, y: 24), in: .screen)
/// ```
public struct ScreenCoordinateSpace: CoordinateSpaceProtocol, Equatable, Sendable {
    /// Creates the typed screen coordinate-space marker.
    public init() {}

    /// The stored `.screen` representation.
    public var coordinateSpace: CoordinateSpace {
        .screen
    }
}
