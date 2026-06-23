import Swift

struct Player {
    private let size: Vec2 = .init(x: 36, y: 36)
    private var controller: TopPlayerController = .slippery
    private var timeline: SpriteAnimation.Timeline = .init(animation: .walk)
    private var wasJumpPressed = false

    var entity: Entity

    init(entityID: Entity.ID) {
        self.entity = .init(
            id: entityID,
            position: .zero,
            size: size,
            collider: Collider(
                bounds: Rect(
                    origin: .zero,
                    size: size
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            )
        )
    }

    var sprite: Sprite {
        Sprite(
            position: entity.position,
            size: entity.size,
            material: .sprite(
                timeline.animation.textureID,
                sourceRect: timeline.frame
            )
        )
    }

    public mutating func place(at position: Vec2) {
        entity.move(
            to: Vec2(
                x: position.x - (size.x / 2),
                y: position.y - (size.y / 2)
            ),
            velocity: .zero
        )
    }

    public mutating func update(context: inout Game.Context) {
        let input = context.input

        timeline.update(delta: context.delta)

        defer {
            wasJumpPressed = input.jump
        }

        let velocity = controller.velocity(
            for: input,
            current: entity.velocity,
            delta: context.delta
        )

        context.move(entity: &entity, velocity: velocity)

        if input.jump && !wasJumpPressed {
            context.play(sound: .jump)
        }
    }
}

private extension SpriteAnimation {
    static let walk: SpriteAnimation = .init(
        textureID: .player,
        frames: [
            Rect(x: 0, y: 0, width: 48, height: 48),
            Rect(x: 48, y: 0, width: 48, height: 48),
            Rect(x: 96, y: 0, width: 48, height: 48),
            Rect(x: 144, y: 0, width: 48, height: 48)
        ],
        frameDuration: 0.12
    )
}
