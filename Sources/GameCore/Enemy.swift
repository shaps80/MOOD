import Swift

struct Enemy: Entity {
    var size: Vec2 {
        .init(x: 16, y: 16)
    }

    var colliders: [Collider] {
        [.init(
            bounds: .init(
                origin: .zero,
                size: size
            ),
            layer: .enemy,
            mask: .player
        )]
    }

    func onUpdate(context: inout Game.Context, state: inout EntityState) {
        
    }

    func onCollision(context: inout Game.Context, state: inout EntityState, contact: Contact) {
        guard contact.phase == .began else { return }
        print(contact)
    }

    func sprite(for state: EntityState) -> Sprite? {
        .init(
            position: state.position,
            size: state.size,
            material: .color(.red)
        )
    }
}
