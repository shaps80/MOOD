import Swift

final class EntityStore {
    private var entitiesByID: [EntityID: EntityState] = [:]

    private(set) subscript(id: EntityID) -> EntityState? {
        get {
            entitiesByID[id]
        }
        set {
            entitiesByID[id] = newValue
        }
    }

    func insert(_ entity: EntityState) {
        entitiesByID[entity.id] = entity
    }

    func update(
        _ id: EntityID,
        _ body: (inout EntityState) -> Void
    ) {
        guard var entity = entitiesByID[id] else {
            return
        }

        body(&entity)
        entitiesByID[id] = entity
    }

    func bounds(for id: EntityID) -> Rect? {
        entitiesByID[id]?.bounds
    }

    func forEachCollider(_ body: (EntityID, Int, Collider) -> Void) {
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
