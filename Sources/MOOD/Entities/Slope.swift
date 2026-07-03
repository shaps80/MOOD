import Pixl

struct Slope: Entity {
    private let size = Vec2(x: 96, y: 16)

    mutating func prepare(context: inout Game.PreparationContext, state: inout EntityState) {
        state.transform.rotation = .degrees(-22)
        state.colliders = [
            Collider(
                bounds: Rect(size: size),
                shape: .rect,
                layer: .world,
                mask: .player,
                behaviour: .blocking
            )
        ]
        state.sprite = Sprite(
            material: .shape(Rectangle(), size: size),
            layer: .world,
            tint: Color(red: 0.32, green: 0.36, blue: 0.42, alpha: 1)
        )
    }

    mutating func onUpdate(context: inout Game.Context, state: inout EntityState) {
    }
}
