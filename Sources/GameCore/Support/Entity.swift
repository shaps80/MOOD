import Swift

public struct Entity: Equatable, Identifiable, Sendable {
    public struct ID: Hashable, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    public let id: ID
    internal var size: Vec2
    internal var position: Vec2
    internal var velocity: Vec2
    internal var colliders: [Collider]

    public init(id: ID, position: Vec2, size: Vec2, collider: Collider? = nil) {
        self.init(
            id: id,
            position: position,
            size: size,
            colliders: collider.map { [$0] } ?? []
        )
    }

    public init(id: ID, position: Vec2, size: Vec2, colliders: [Collider]) {
        self.id = id
        self.position = position
        self.size = size
        self.velocity = .zero
        self.colliders = colliders
    }

    mutating func move(to position: Vec2, velocity: Vec2) {
        self.position = position
        self.velocity = velocity
    }

    var colliderWorldBounds: Rect? {
        colliders.first?.worldBounds(at: position)
    }

    var colliderWorldBoundsList: [Rect] {
        colliders.map { $0.worldBounds(at: position) }
    }

    public var bounds: Rect {
        Rect(origin: position, size: size)
    }
}

extension Entity.ID {
    static let player = Entity.ID(rawValue: 0)
    static let pickup = Entity.ID(rawValue: 1)
}
