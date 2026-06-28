import Pixl

struct Enemy: Entity {
    private let baseSize = Vec2(x: 16, y: 32)

    mutating func prepare(context: inout Game.PreparationContext, state: inout EntityState) {
        state.colliders = [
            .init(
                bounds: Rect(size: baseSize),
                layer: .enemy,
                mask: .player
            )
        ]
        state.sprite = Sprite(
            material: .shape(Capsule(), size: baseSize),
            layer: .entity,
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
