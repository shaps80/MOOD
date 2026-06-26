import Swift

struct Player: Entity {
    let size: Vec2 = .init(x: 32, y: 32)
    private var controller: TopPlayerController = .slippery
    private var timeline: SpriteAnimation.Timeline = .init(animation: .walk)
    private var wasJumpPressed = false

    var colliders: [Collider] {
        [.init(
            bounds: Rect(origin: .zero, size: size)
                .padding(.left, 8)
                .padding(.right, 9)
                .padding(.vertical, 3),
            layer: .player,
            mask: [.playerMovement, .pickup],
            behaviour: .blocking
        )]
    }

    func sprite(for state: EntityState) -> Sprite? {
        Sprite(
            position: state.position,
            size: state.size,
            material: .sprite(
                timeline.animation.textureID,
                sourceRect: timeline.frame
            )
        )
    }

    mutating func onUpdate(context: inout Game.Context, state: inout EntityState) {
        let input = context.input

        timeline.update(delta: context.delta)

        defer {
            wasJumpPressed = input.jump
        }

        let velocity = controller.velocity(
            for: input,
            current: state.velocity,
            delta: context.delta
        )

        context.move(state: &state, velocity: velocity)
    }

    mutating func onCollision(
        context: inout Game.Context,
        state: inout EntityState,
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
