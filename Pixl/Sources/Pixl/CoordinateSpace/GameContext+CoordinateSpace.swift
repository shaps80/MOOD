import Pixl2D

public extension GameContext {
    /// Converts a point between logical screen and camera-resolved world coordinates.
    func convert(
        _ point: Vec2,
        from source: CoordinateSpace,
        to destination: CoordinateSpace
    ) -> Vec2 {
        switch (source, destination) {
        case (.screen, .screen), (.world, .world):
            return point
        default:
            return coordinateConverter?.convert(
                point,
                from: source,
                to: destination
            ) ?? .invalid
        }
    }

    /// Converts bounds between logical screen and camera-resolved world coordinates.
    func convert(
        _ bounds: Rect,
        from source: CoordinateSpace,
        to destination: CoordinateSpace
    ) -> Rect {
        switch (source, destination) {
        case (.screen, .screen), (.world, .world):
            return bounds
        default:
            return coordinateConverter?.convert(
                bounds,
                from: source,
                to: destination
            ) ?? .invalid
        }
    }
}
