import Pixl

struct Player: Entity {
    private var horizontal = AxisController(
        maxSpeed: 320,
        acceleration: 1800,
        deceleration: 2200
    )
    private var gun = Gun(roundsPerSecond: 10)

    mutating func prepare(context: inout Game.PreparationContext, state: inout EntityState) {
        state.sprite = Sprite(
            material: .shape(
                RoundedRectangle(cornerRadius: 8),
                size: GameConfig.playerSize
            ),
            layer: .player,
            tint: .blue
        )
        state.colliders = [
            Collider(
                bounds: Rect(size: GameConfig.playerSize),
                layer: .player,
                mask: [.playerMovement, .invader],
                behaviour: .blocking
            )
        ]
    }

    mutating func onUpdate(context: inout Game.Context, state: inout EntityState) {
        gun.update(delta: context.delta)

        state.velocity = Vec2(
            x: horizontal.velocity(
                current: state.velocity.x,
                input: context.input.horizontal,
                delta: context.delta
            ),
            y: 0
        )

        if context.input.jump, gun.fire() {
            context.spawn(
                Bullet.self,
                at: Vec2(
                    x: (GameConfig.playerSize.x - GameConfig.bulletSize.x) / 2,
                    y: -GameConfig.bulletSize.y
                ),
                in: .entity(state.id)
            )
            context.play(sound: .laser)
        }
    }

    mutating func onCollision(
        context: inout Game.Context,
        state: inout EntityState,
        contact: Contact
    ) {
        guard contact.phase == .began,
              contact.target.id != nil
        else {
            return
        }

        context.restart()
    }
}

