/// One directed endpoint of a collision report.
public struct CollisionEndpoint2D: Equatable, Sendable {
    public let collider: ColliderID
    /// Exact world-space bounds captured for this collision tick.
    public let bounds: Rect

    package init(collider: ColliderID, bounds: Rect) {
        self.collider = collider
        self.bounds = bounds
    }
}
