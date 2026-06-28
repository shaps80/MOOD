import Pixl

struct Enemy: Entity {
    mutating func prepare(context: inout Game.PreparationContext, state: inout EntityState) {
        state.size = .init(x: 16, y: 16)
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
//        state.sprite = Sprite(
//            position: state.position,
//            size: state.size,
//            material: .color(.red),
//            layer: .entity
//        )
    }

    mutating func onUpdate(context: inout Game.Context, state: inout EntityState) {
        let position = state.position
        let size = state.size
        state.sprite?.position = position
        state.sprite?.size = size

        let path = RoundedRectangle(cornerRadius: 28)
            .fill(.blue)

        context.draw(path, in: .init(origin: state.position, size: .init(x: 300, y: 300)))
    }

    mutating func onCollision(context: inout Game.Context, state: inout EntityState, contact: Contact) {
        guard contact.phase == .began else { return }
        print(contact)
    }
}
