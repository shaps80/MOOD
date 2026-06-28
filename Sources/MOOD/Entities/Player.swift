import Pixl

struct Player: Entity {
    private var controller: TopPlayerController = .slippery
    private var timeline: SpriteAnimation.Timeline = .init(animation: .walk)
    private var wasJumpPressed = false

    func onCollision(context: inout Game.Context, state: inout EntityState, contact: Contact) {
        guard contact.phase == .began else { return }
        print(contact)
    }

    mutating func prepare(context: inout Game.PreparationContext, state: inout EntityState) {
        state.size = .init(x: 32, y: 32)
        state.colliders = [
            .init(
                bounds: Rect(origin: .zero, size: state.size)
                    .padding(.left, 8)
                    .padding(.right, 9)
                    .padding(.vertical, 3),
                layer: .player,
                mask: [.playerMovement, .pickup],
                behaviour: .blocking
            )
        ]
        state.sprite = Sprite(
            position: state.position,
            size: state.size,
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

        context.move(state: &state, velocity: velocity)
        let position = state.position
        let size = state.size
        state.sprite?.position = position
        state.sprite?.size = size
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
