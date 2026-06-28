import Swift

public struct EntityID: Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct EntityState: Equatable, Identifiable, Sendable {
    public let id: EntityID
    public internal(set) var position: Vec2
    public internal(set) var velocity: Vec2
    public var sprite: Sprite?
    public var colliders: [Collider]

    public init(id: EntityID, collider: Collider? = nil) {
        self.init(id: id, colliders: collider.map { [$0] } ?? [])
    }

    public init(id: EntityID, colliders: [Collider]) {
        self.id = id
        self.position = .zero
        self.velocity = .zero
        self.sprite = nil
        self.colliders = colliders
    }

    mutating func move(to position: Vec2, velocity: Vec2) {
        self.position = position
        self.velocity = velocity
    }

    mutating func finalizePreparation() {
    }

    var colliderFrames: [Rect] {
        worldColliders.map(\.bounds)
    }

    var worldColliders: [Collider] {
        let spriteSize = sprite?.naturalSize ?? .zero
        let spriteScale = sprite?.scale ?? Vec2(x: 1, y: 1)

        return colliders.map {
            $0.placed(
                at: position,
                spriteSize: spriteSize,
                scale: spriteScale
            )
        }
    }

    public var bounds: Rect {
        guard let sprite else {
            return Rect(center: position, size: .zero)
        }

        return Rect(center: position, size: sprite.naturalSize * sprite.scale)
    }
}
