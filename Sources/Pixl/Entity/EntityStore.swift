import Swift

final class EntityStore {
    private var entities: [any Entity] = []
    private var states: [EntityState] = []
    private var indicesByID: [EntityID: Int] = [:]
    private var nextEntityID: Int = 0

    private(set) subscript(id: EntityID) -> EntityState? {
        get {
            guard let index = indicesByID[id] else {
                return nil
            }

            return states[index]
        }
        set {
            guard let index = indicesByID[id] else {
                return
            }

            if let newValue {
                states[index] = newValue
            } else {
                entities.remove(at: index)
                states.remove(at: index)
                rebuildIndices()
            }
        }
    }

    func insert(entity: any Entity, state: EntityState) {
        guard indicesByID[state.id] == nil else {
            assertionFailure("Duplicate entity id: \(state.id)")
            return
        }

        indicesByID[state.id] = entities.count
        entities.append(entity)
        states.append(state)
        reserveID(after: state.id)
    }

    func remove(_ id: EntityID) {
        guard let index = indicesByID[id] else {
            return
        }

        entities.remove(at: index)
        states.remove(at: index)
        rebuildIndices()
    }

    func allocateID() -> EntityID {
        while indicesByID[EntityID(rawValue: nextEntityID)] != nil {
            nextEntityID += 1
        }

        defer {
            nextEntityID += 1
        }

        return EntityID(rawValue: nextEntityID)
    }

    func update(
        _ id: EntityID,
        _ body: (inout EntityState) -> Void
    ) {
        guard let index = indicesByID[id] else {
            return
        }

        body(&states[index])
    }

    func updateEach(
        _ body: (inout any Entity, inout EntityState) -> Void
    ) {
        for index in entities.indices {
            body(&entities[index], &states[index])
        }
    }

    func applyMovement(collisionSystem: CollisionSystem) {
        for index in states.indices {
            var state = states[index]

            collisionSystem.move(state: &state, velocity: state.velocity)

            states[index] = state
        }
    }

    func updateEachWithContacts(
        contacts: ContactState,
        _ body: (inout any Entity, inout EntityState, Contact) -> Void
    ) {
        for index in entities.indices {
            let entityID = states[index].id

            for contact in contacts[entityID] {
                body(&entities[index], &states[index], contact)
            }
        }
    }

    func forEachState(_ body: (EntityState) -> Void) {
        for state in states {
            body(state)
        }
    }

    func bounds(for id: EntityID) -> Rect? {
        self[id]?.bounds
    }

    func forEachCollider(_ body: (EntityID, Int, Collider) -> Void) {
        for state in states {
            let colliders = state.worldColliders

            for index in colliders.indices {
                body(
                    state.id,
                    index,
                    colliders[index]
                )
            }
        }
    }

    private func rebuildIndices() {
        indicesByID.removeAll(keepingCapacity: true)

        for index in entities.indices {
            indicesByID[states[index].id] = index
        }
    }

    private func reserveID(after id: EntityID) {
        nextEntityID = max(nextEntityID, id.rawValue + 1)
    }
}
