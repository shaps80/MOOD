import Pixl

struct Enemy: Entity {
    private let size = Vec2(x: 16, y: 32)

    mutating func prepare(context: inout Game.PreparationContext, state: inout EntityState) {
        state.colliders = [
            .init(
                bounds: Rect(size: size),
                layer: .enemy,
                mask: .player
            )
        ]
        state.sprite = Sprite(
            material: .shape(Capsule(), size: size),
            layer: .background,
            tint: .red
        )
    }

    mutating func onUpdate(context: inout Game.Context, state: inout EntityState) {
    }

    mutating func onCollision(context: inout Game.Context, state: inout EntityState, contact: Contact) {
        guard contact.phase == .began else { return }
        print(contact)
    }
}
