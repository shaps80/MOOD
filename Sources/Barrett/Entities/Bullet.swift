import Pixl

struct Bullet: Entity {
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
        state.velocity = Vec2(x: 0, y: -520)
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

        if let target = contact.target.id {
            context.despawn(target)
        }
    }
}

