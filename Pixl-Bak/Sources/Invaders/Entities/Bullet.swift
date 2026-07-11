import Pixl

struct Bullet: Entity {
    private var horizontal = AxisController(
        maxSpeed: 120,
        acceleration: 0,
        deceleration: 180
    )
    private var vertical = AxisController(
        maxSpeed: 3000,
        acceleration: 5000,
        deceleration: 500
    )

    mutating func prepare(context: inout Game.PreparationContext, state: inout EntityState) {
        state.sprite = Sprite(
            material: .shape(Capsule(), size: GameConfig.bulletSize),
            layer: .enemy,
            tint: .yellow
        )
        state.colliders = [
            Collider(
                bounds: Rect(size: GameConfig.bulletSize),
                shape: Capsule(),
                layer: .bullet,
                mask: .bulletContact,
                behaviour: .trigger
            )
        ]
    }

    mutating func onUpdate(context: inout Game.Context, state: inout EntityState) {
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
