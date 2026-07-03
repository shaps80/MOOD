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

    /// The world-space center position for the entity.
    public var position: Vec2

    /// The visual rotation for the entity.
    ///
    /// Rotation is clockwise in y-down coordinates. It affects rendering and
    /// visual bounds, but collision remains axis-aligned for now.
    ///
    /// ```swift
    /// state.rotation += .degrees(180) * context.delta
    /// ```
    public var rotation: Angle

    public var velocity: Vec2
    public var sprite: Sprite?
    public var colliders: [Collider]

    public init(id: EntityID, collider: Collider? = nil) {
        self.init(id: id, colliders: collider.map { [$0] } ?? [])
    }

    public init(id: EntityID, colliders: [Collider]) {
        self.id = id
        self.position = .zero
        self.rotation = .zero
        self.velocity = .zero
        self.sprite = nil
        self.colliders = colliders
    }

    var colliderFrames: [Rect] {
        worldColliders.map(\.bounds)
    }

    internal mutating func move(to position: Vec2, velocity: Vec2) {
        self.position = position
        self.velocity = velocity
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

        return RenderTransform(
            center: position,
            size: sprite.naturalSize * sprite.scale,
            rotation: rotation
        ).rotatedBounds
    }
}
