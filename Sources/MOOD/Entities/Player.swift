import Pixl

struct Player: Entity {
    private let size = Vec2(x: 48, y: 48)
    private var controller: TopPlayerController = .slippery
    private var timeline: SpriteAnimation.Timeline = .init(animation: .walk)
    private var wasJumpPressed = false

    mutating func prepare(context: inout Game.PreparationContext, state: inout EntityState) {
        state.colliders = [
            .init(
                bounds: Rect(size: size)
                    .padding(.left, 8)
                    .padding(.right, 9)
                    .padding(.vertical, 3),
                shape: .capsule,
                layer: .player,
                mask: [.playerMovement, .pickup],
                behaviour: .blocking
            )
        ]

        state.sprite = Sprite(
            material: .sprite(
                timeline.animation.textureID,
                sourceRect: timeline.frame
            ),
            layer: .entity
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

        state.rotation += .degrees(180) * context.delta
        state.velocity = velocity
        state.sprite?.material = .sprite(
            timeline.animation.textureID,
            sourceRect: timeline.frame
        )
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
