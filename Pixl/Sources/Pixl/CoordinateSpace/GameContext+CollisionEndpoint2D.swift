import Pixl2D

public extension GameContext {
    /// Converts collision-endpoint bounds between presentation coordinate spaces.
    func convert(
        _ endpoint: CollisionEndpoint2D,
        from source: CoordinateSpace,
        to destination: CoordinateSpace
    ) -> Rect {
        convert(endpoint.bounds, from: source, to: destination)
    }
}
