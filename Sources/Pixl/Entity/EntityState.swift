import Swift

public struct EntityID: Hashable, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public struct EntityState: Equatable, Identifiable, Sendable {
    public let id: EntityID
    public var size: Vec2 {
        get { storedSize }
        set {
            storedSize = newValue
            hasExplicitSize = true
        }
    }
    public internal(set) var position: Vec2
    public internal(set) var velocity: Vec2
    public var sprite: Sprite?
    public var colliders: [Collider]
    private var storedSize: Vec2
    private var hasExplicitSize: Bool

    public init(id: EntityID, size: Vec2 = .zero, collider: Collider? = nil) {
        self.init(
            id: id,
            size: size,
            colliders: collider.map { [$0] } ?? []
        )
    }

    public init(id: EntityID, size: Vec2, colliders: [Collider]) {
        self.id = id
        self.position = .zero
        self.storedSize = size
        self.hasExplicitSize = size != .zero
        self.velocity = .zero
        self.sprite = nil
        self.colliders = colliders
    }

    mutating func move(to position: Vec2, velocity: Vec2) {
        self.position = position
        self.velocity = velocity
    }

    mutating func finalizePreparation() {
        guard !hasExplicitSize else { return }

        storedSize = sprite?.size ?? .zero
    }

    var colliderFrames: [Rect] {
        colliders.map { $0.worldBounds(at: position) }
    }

    var worldColliders: [Collider] {
        colliders.map { $0.placed(at: position) }
    }

    public var bounds: Rect {
        Rect(origin: position, size: size)
    }
}
