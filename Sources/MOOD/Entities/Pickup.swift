import Pixl

struct Pickup: Entity {
    mutating func prepare(context: inout Game.PreparationContext, state: inout EntityState) {
        state.size = .init(x: 16, y: 16)
        state.colliders = [
            Collider(
                bounds: Rect(origin: .zero, size: state.size),
                layer: .pickup,
                mask: .player,
                behaviour: .trigger
            )
        ]
        state.sprite = Sprite(
            position: state.position,
            size: state.size,
            material: .shape(Rectangle()),
            layer: .entity,
            tint: .yellow
        )
    }

    mutating func onUpdate(context: inout Game.Context, state: inout EntityState) {
        let position = state.position
        let size = state.size
        state.sprite?.position = position
        state.sprite?.size = size
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
