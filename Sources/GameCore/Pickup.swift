import Swift

struct Pickup: Entity {
    let size: Vec2 = .init(x: 16, y: 16)

    var colliders: [Collider] {
        [
            Collider(
                bounds: Rect(origin: .zero, size: size),
                layer: .pickup,
                mask: .player,
                behaviour: .trigger
            )
        ]
    }

    func sprite(for state: EntityState) -> Sprite? {
        Sprite(
            position: state.position,
            size: state.size,
            material: .color(.yellow)
        )
    }

    mutating func onUpdate(context: inout Game.Context, state: inout EntityState) {}

    mutating func onCollision(
        context: inout Game.Context,
        state: inout EntityState,
        contact: Contact
    ) {
        guard contact.phase == .began, contact.target.id == .player else { return }
        context.play(sound: .jump)
    }
}
