import Swift

struct Pickup {
    private let size: Vec2 = .init(x: 16, y: 16)
    private let center: Vec2

    let entityID: Entity.ID

    init(entityID: Entity.ID, center: Vec2) {
        self.entityID = entityID
        self.center = center
    }

    func makeEntity() -> Entity {
        Entity(
            id: entityID,
            position: Vec2(
                x: center.x - (size.x / 2),
                y: center.y - (size.y / 2)
            ),
            size: size
        )
    }

    func sprite(for entity: Entity) -> Sprite {
        Sprite(
            position: entity.position,
            size: entity.size,
            material: .color(.red)
        )
    }
}
