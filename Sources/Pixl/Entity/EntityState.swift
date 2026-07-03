import Swift

public struct EntityID: Hashable, Sendable, ExpressibleByIntegerLiteral {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public init(integerLiteral value: Int) {
        rawValue = value
    }
}

public struct EntityState: Equatable, Identifiable, Sendable {
    public let id: EntityID

    /// The world-space entity transform.
    ///
    /// Child sprite and collider transforms are composed with this transform.
    ///
    /// ```swift
    /// state.transform.rotation += .degrees(180) * context.delta
    /// ```
    public var transform: Transform

    public var velocity: Vec2
    public var sprite: Sprite?
    public var colliders: [Collider]

    public init(id: EntityID, collider: Collider? = nil) {
        self.init(id: id, colliders: collider.map { [$0] } ?? [])
    }

    public init(id: EntityID, colliders: [Collider]) {
        self.id = id
        self.transform = .identity
        self.velocity = .zero
        self.sprite = nil
        self.colliders = colliders
    }

    var colliderFrames: [Rect] {
        worldColliders.map(\.bounds)
    }

    internal mutating func move(to position: Vec2, velocity: Vec2) {
        self.transform.position = position
        self.velocity = velocity
    }

    var worldColliders: [Collider] {
        let spriteSize = sprite?.naturalSize ?? .zero

        return colliders.map {
            $0.placed(
                in: transform,
                spriteSize: spriteSize
            )
        }
    }

    public var bounds: Rect {
        guard let sprite else {
            return Rect(center: transform.position, size: .zero)
        }

        let worldTransform = transform.concatenated(with: sprite.transform)
        return RenderTransform(
            center: worldTransform.position,
            size: sprite.naturalSize * worldTransform.scale,
            rotation: worldTransform.rotation
        ).rotatedBounds
    }
}
