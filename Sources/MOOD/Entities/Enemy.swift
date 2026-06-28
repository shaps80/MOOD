import Pixl

struct Enemy: Entity {
    mutating func prepare(context: inout Game.PreparationContext, state: inout EntityState) {
        state.size = .init(x: 16, y: 32)
        state.colliders = [
            .init(
                bounds: .init(
                    origin: .zero,
                    size: state.size
                ),
                layer: .enemy,
                mask: .player
            )
        ]
        state.sprite = Sprite(
            position: state.position,
            size: state.size,
            material: .shape(Capsule()),
            layer: .entity,
            tint: .red
        )
    }

    mutating func onUpdate(context: inout Game.Context, state: inout EntityState) {
        let position = state.position
        let size = state.size
        state.sprite?.position = position
        state.sprite?.size = size
    }

    mutating func onCollision(context: inout Game.Context, state: inout EntityState, contact: Contact) {
        guard contact.phase == .began else { return }
        print(contact)
    }
}
