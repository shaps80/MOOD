import Pixl

struct Player: Entity {
    private let size = Vec2(x: 16, y: 16)

    mutating func prepare(context: inout Game.PreparationContext, state: inout EntityState) {
        state.sprite = Sprite(
            material: .shape(.capsule, size: .init(x: 16, y: 16)),
            layer: .entity,
            tint: .red
        )
    }

    mutating func onUpdate(context: inout Game.Context, state: inout EntityState) {

    }
}
