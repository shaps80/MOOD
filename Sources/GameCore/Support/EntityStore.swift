import Swift

final class EntityStore {
    private var entitiesByID: [Entity.ID: Entity] = [:]

    private(set) subscript(id: Entity.ID) -> Entity? {
        get {
            entitiesByID[id]
        }
        set {
            entitiesByID[id] = newValue
        }
    }

    func insert(_ entity: Entity) {
        entitiesByID[entity.id] = entity
    }

    func update(
        _ id: Entity.ID,
        _ body: (inout Entity) -> Void
    ) {
        guard var entity = entitiesByID[id] else {
            return
        }

        body(&entity)
        entitiesByID[id] = entity
    }

    func bounds(for id: Entity.ID) -> Rect? {
        entitiesByID[id]?.bounds
    }

    func forEachCollider(_ body: (Entity.ID, Int, Collider) -> Void) {
        for entity in entitiesByID.values {
            for index in entity.colliders.indices {
                body(
                    entity.id,
                    index,
                    entity.colliders[index].placed(at: entity.position)
                )
            }
        }
    }
}
