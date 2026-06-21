import Swift

struct Player {
    private let size: Vec2 = .init(x: 16, y: 16)
    var entity: Entity
    var speed: Double = 200

    static let `default` = Player()

    private init() {
        self.entity = .init(
            position: .zero,
            size: size,
            asset: .player
        )
    }

    public mutating func place(in worldSize: Vec2) {
        entity.position = .init(
            x: (worldSize.x - size.x) / 2,
            y: (worldSize.y - size.y) / 2
        )
    }

    public mutating func update(delta: Double, input: InputState, worldSize: Vec2) {
        let step = max(delta, 0)
        let leftBound = 0.0
        let rightBound = worldSize.x - entity.size.x
        let topBound = 0.0
        let bottomBound = worldSize.y - entity.size.y

        let velocity = Vec2(
            x: input.horizontal * speed,
            y: input.vertical * speed
        )

        let nextX = clamp(
            entity.position.x + (velocity.x * step),
            min: leftBound,
            max: rightBound
        )

        let nextY = clamp(
            entity.position.y + (velocity.y * step),
            min: topBound,
            max: bottomBound
        )

        entity.move(
            to: Vec2(x: nextX, y: nextY),
            velocity: velocity
        )
    }
}
