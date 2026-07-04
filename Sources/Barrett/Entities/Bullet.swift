import Pixl

struct Bullet: Entity {
    private var vertical = AxisController(
        maxSpeed: 2000,
        acceleration: 5000,
        deceleration: 1000
    )

    mutating func prepare(context: inout Game.PreparationContext, state: inout EntityState) {
        state.sprite = Sprite(
            material: .shape(Rectangle(), size: GameConfig.bulletSize),
            layer: .enemy,
            tint: .yellow
        )
        state.colliders = [
            Collider(
                bounds: Rect(size: GameConfig.bulletSize),
                layer: .bullet,
                mask: .bulletContact,
                behaviour: .trigger
            )
        ]
    }

    mutating func onUpdate(context: inout Game.Context, state: inout EntityState) {
        state.velocity = Vec2(
            x: 0,
            y: vertical.velocity(
                current: state.velocity.y,
                input: -1,
                delta: context.delta
            )
        )
    }

    mutating func onCollision(
        context: inout Game.Context,
        state: inout EntityState,
        contact: Contact
    ) {
        guard contact.phase == .began else {
            return
        }

        context.despawn(state.id)

        if contact.target.id != nil {
            context.play(sound: .hit)
        }
    }
}
