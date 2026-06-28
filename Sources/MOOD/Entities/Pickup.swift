import Pixl

struct Pickup: Entity {
    private let size = Vec2(x: 16, y: 16)

    mutating func prepare(context: inout Game.PreparationContext, state: inout EntityState) {
        state.colliders = [
            Collider(
                bounds: Rect(size: size),
                layer: .pickup,
                mask: .player,
                behaviour: .trigger
            )
        ]
        state.sprite = Sprite(
            material: .shape(Rectangle(), size: size),
            layer: .entity,
            tint: .yellow
        )
    }

    mutating func onUpdate(context: inout Game.Context, state: inout EntityState) {
    }

    mutating func onCollision(
        context: inout Game.Context,
        state: inout EntityState,
        contact: Contact
    ) {
        guard contact.phase == .began, contact.target.id == .player else { return }
        context.play(sound: .jump)
    }
}
