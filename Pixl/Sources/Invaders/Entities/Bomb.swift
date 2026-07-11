import Pixl

struct Bomb: Entity {
    private enum Mode {
        case traveling
        case exploding(elapsed: Double)
    }

    private var horizontal = AxisController(
        maxSpeed: 120,
        acceleration: 0,
        deceleration: 140
    )
    private var vertical = AxisController(
        maxSpeed: 300,
        acceleration: 2000,
        deceleration: 1000
    )
    private var mode: Mode = .traveling
    private let explosionDuration: Double = 0.16

    mutating func prepare(context: inout Game.PreparationContext, state: inout EntityState) {
        state.sprite = Sprite(
            material: .shape(Circle(), size: GameConfig.bombSize),
            layer: .player,
            tint: .blue
        )
        state.colliders = [
            Collider(
                bounds: Rect(size: GameConfig.bombSize),
                shape: Circle(),
                layer: .bullet,
                mask: .bulletContact,
                behaviour: .trigger
            )
        ]
    }

    mutating func onUpdate(context: inout Game.Context, state: inout EntityState) {
        switch mode {
        case .traveling:
            state.velocity = Vec2(
                x: horizontal.velocity(
                    current: state.velocity.x,
                    input: 0,
                    delta: context.delta
                ),
                y: vertical.velocity(
                    current: state.velocity.y,
                    input: -1,
                    delta: context.delta
                )
            )
        case .exploding(let elapsed):
            let nextElapsed = elapsed + context.delta
            let progress = min(nextElapsed / explosionDuration, 1)
            let pulse = sin(.degrees(progress * 180))

            state.velocity = .zero
            state.sprite?.transform.scale = Vec2(1 + (0.35 * pulse))
            updateBlastCollider(state: &state, progress: progress)

            if nextElapsed >= explosionDuration {
                context.despawn(state.id)
            } else {
                mode = .exploding(elapsed: nextElapsed)
            }
        }
    }

    mutating func onCollision(
        context: inout Game.Context,
        state: inout EntityState,
        contact: Contact
    ) {
        guard contact.phase == .began else {
            return
        }

        switch mode {
        case .traveling:
            if contact.target.id != nil {
                mode = .exploding(elapsed: 0)
                state.velocity = .zero
            } else {
                context.despawn(state.id)
            }
        case .exploding:
            break
        }
    }

    private func updateBlastCollider(state: inout EntityState, progress: Double) {
        guard !state.colliders.isEmpty else {
            return
        }

        let size = Vec2(
            GameConfig.bombSize.x
                + (((GameConfig.bombRadius * 2) - GameConfig.bombSize.x) * progress)
        )

        state.colliders[0].bounds = Rect(
            origin: Vec2(
                x: (GameConfig.bombSize.x - size.x) / 2,
                y: (GameConfig.bombSize.y - size.y) / 2
            ),
            size: size
        )
    }
}
