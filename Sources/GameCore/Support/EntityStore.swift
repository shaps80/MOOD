import Swift

struct EntityStore: Equatable, Sendable {
    private var entitiesByID: [Entity.ID: Entity] = [:]

    private(set) subscript(id: Entity.ID) -> Entity? {
        get {
            entitiesByID[id]
        }
        set {
            entitiesByID[id] = newValue
        }
    }

    mutating func insert(_ entity: Entity) {
        entitiesByID[entity.id] = entity
    }

    mutating func modify(
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
}
