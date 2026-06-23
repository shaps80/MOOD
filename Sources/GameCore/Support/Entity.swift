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
    internal var collider: Collider?

    public init(id: ID, position: Vec2, size: Vec2, collider: Collider? = nil) {
        self.id = id
        self.position = position
        self.size = size
        self.velocity = .zero
        self.collider = collider
    }

    mutating func move(to position: Vec2, velocity: Vec2) {
        self.position = position
        self.velocity = velocity
    }

    var colliderWorldBounds: Rect? {
        collider?.worldBounds(at: position)
    }

    public var bounds: Rect {
        Rect(origin: position, size: size)
    }
}

extension Entity.ID {
    static let player = Entity.ID(rawValue: 0)
}
