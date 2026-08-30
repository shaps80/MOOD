/// Nearest exact collider intersection returned by a collision-world ray cast.
public struct ColliderRayHit2D: Equatable, Sendable {
    /// Collider whose exact bounds were intersected.
    public let collider: ColliderID
    /// Exact rectangle intersection.
    public let hit: RayHit2D

    package init(collider: ColliderID, hit: RayHit2D) {
        self.collider = collider
        self.hit = hit
    }
}
