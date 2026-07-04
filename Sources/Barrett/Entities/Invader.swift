import Pixl

struct Invader: Entity {
    mutating func prepare(context: inout Game.PreparationContext, state: inout EntityState) {
        state.sprite = Sprite(
            material: .shape(Capsule(), size: GameConfig.invaderSize),
            layer: .entity,
            tint: .red
        )
        state.colliders = [
            Collider(
                bounds: Rect(size: GameConfig.invaderSize),
                layer: .invader,
                mask: .invaderContact,
                behaviour: .trigger
            )
        ]
    }

    mutating func onUpdate(context: inout Game.Context, state: inout EntityState) {
        state.velocity = .zero
    }

    mutating func onCollision(
        context: inout Game.Context,
        state: inout EntityState,
        contact: Contact
    ) {
        guard contact.phase == .began else {
            return
        }

        if contact.target.id != nil {
            context.camera.shake()
            context.despawn(state.id)
        } else if contact.target.tile?.row == Int(GameConfig.resolution.y / GameConfig.tileSize.y) - 1 {
            context.restart()
        }
    }
}
