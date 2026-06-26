import Swift

struct Player {
    private let size: Vec2 = .init(x: 32, y: 32)
    private var controller: TopPlayerController = .slippery
    private var timeline: SpriteAnimation.Timeline = .init(animation: .walk)
    private var wasJumpPressed = false

    let entityID: Entity.ID

    init(entityID: Entity.ID) {
        self.entityID = entityID
    }

    func makeEntity() -> Entity {
        Entity(
            id: entityID,
            position: .zero,
            size: size,
            collider: .init(
                bounds: .init(
                    origin: .zero,
                    size: size
                )
                .padding(.left, 8)
                .padding(.right, 9)
                .padding(.vertical, 3),
                layer: .player,
                mask: [.playerMovement, .pickup],
                behaviour: .blocking
            )
        )
    }

    func sprite(for entity: Entity) -> Sprite {
        Sprite(
            position: entity.position,
            size: entity.size,
            material: .sprite(
                timeline.animation.textureID,
                sourceRect: timeline.frame
            )
        )
    }

    func place(entity: inout Entity, at position: Vec2) {
        entity.move(
            to: Vec2(
                x: position.x - (size.x / 2),
                y: position.y - (size.y / 2)
            ),
            velocity: .zero
        )
    }

    public mutating func update(context: inout Game.Context, entity: inout Entity) {
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

//        if input.jump && !wasJumpPressed {
//            context.play(sound: .jump)
//        }
    }

    mutating func onCollision(
        context: inout Game.Context,
        entity: inout Entity,
        contact: Contact
    ) { }
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
