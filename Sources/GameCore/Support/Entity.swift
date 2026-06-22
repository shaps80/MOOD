import Swift

public struct Entity: Equatable, Sendable {
    internal var size: Vec2
    internal var position: Vec2
    internal var velocity: Vec2
    /// Optional local-space collider. Entities without colliders move freely.
    internal var collider: Collider?

    public init(position: Vec2, size: Vec2, collider: Collider? = nil) {
        self.position = position
        self.size = size
        self.velocity = .zero
        self.collider = collider
    }

    mutating func move(to position: Vec2, velocity: Vec2) {
        self.position = position
        self.velocity = velocity
    }
}
