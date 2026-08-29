import Pixl2D

/// A game-facing coordinate space used to resolve presentation input.
public enum CoordinateSpace: Sendable {
    /// Logical screen points with a top-left origin and positive y downward.
    case screen

    /// Y-up world coordinates viewed through a two-dimensional camera.
    case world(any Camera2D)
}
