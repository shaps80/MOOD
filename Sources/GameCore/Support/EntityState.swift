import Swift

public struct EntityID: Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct EntityState: Equatable, Identifiable, Sendable {
    public let id: EntityID
    internal var size: Vec2
    internal var position: Vec2
    internal var velocity: Vec2
    internal var colliders: [Collider]

    public init(id: EntityID, size: Vec2, collider: Collider? = nil) {
        self.init(
            id: id,
            size: size,
            colliders: collider.map { [$0] } ?? []
        )
    }

    public init(id: EntityID, size: Vec2, colliders: [Collider]) {
        self.id = id
        self.position = .zero
        self.size = size
        self.velocity = .zero
        self.colliders = colliders
    }

    mutating func move(to position: Vec2, velocity: Vec2) {
        self.position = position
        self.velocity = velocity
    }

    var colliderFrames: [Rect] {
        colliders.map { $0.worldBounds(at: position) }
    }

    public var bounds: Rect {
        Rect(origin: position, size: size)
    }
}

extension EntityID {
    static let player = EntityID(rawValue: 0)
    static let pickup = EntityID(rawValue: 1)
    static let enemy = EntityID(rawValue: 2)
}
