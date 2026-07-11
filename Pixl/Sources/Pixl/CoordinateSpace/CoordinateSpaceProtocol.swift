import Swift

/// A type that can describe a Pixl coordinate space.
///
/// Use concrete coordinate-space values when an API wants SwiftUI-style typed
/// spaces, or use `CoordinateSpace` directly when storing the selected space.
///
/// ```swift
/// let space: some CoordinateSpaceProtocol = WorldCoordinateSpace()
/// let coordinateSpace = space.coordinateSpace
/// ```
public protocol CoordinateSpaceProtocol: Sendable {
    /// The stored coordinate-space representation.
    var coordinateSpace: CoordinateSpace { get }
}

public extension CoordinateSpaceProtocol where Self == WorldCoordinateSpace {
    /// World coordinates.
    ///
    /// ```swift
    /// context.spawn(Bullet.self, at: .zero, in: .world)
    /// ```
    static var world: WorldCoordinateSpace {
        WorldCoordinateSpace()
    }
}

public extension CoordinateSpaceProtocol where Self == ScreenCoordinateSpace {
    /// Screen coordinates relative to the current camera viewport.
    ///
    /// ```swift
    /// context.spawn(Bullet.self, at: Vec2(x: 80, y: 24), in: .screen)
    /// ```
    static var screen: ScreenCoordinateSpace {
        ScreenCoordinateSpace()
    }
}

