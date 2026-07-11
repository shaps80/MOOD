import Swift

final class EntityStore {
    private struct Slot {
        var generation: Int = 0
        var entity: (any Entity)?
        var state: EntityState?
        var activeIndex: Int?
        var nextFree: Int?
        var isReserved = false

        var isActive: Bool {
            entity != nil && state != nil && activeIndex != nil
        }
    }

    private var slots: [Slot] = []
    private var activeSlots: [Int] = []
    private var freeHead: Int?

    subscript(id: EntityID) -> EntityState? {
        get {
            guard let slotIndex = validSlotIndex(for: id),
                  slots[slotIndex].isActive
            else {
                return nil
            }

            return slots[slotIndex].state
        }
        set {
            guard let slotIndex = validSlotIndex(for: id),
                  slots[slotIndex].isActive
            else {
                return
            }

            if let newValue {
                slots[slotIndex].state = newValue
            } else {
                remove(id)
            }
        }
    }

    func reserveID() -> EntityID {
        let slotIndex: Int

        if let freeIndex = freeHead {
            slotIndex = freeIndex
            freeHead = slots[freeIndex].nextFree
            slots[freeIndex].nextFree = nil
        } else {
            slotIndex = slots.count
            slots.append(Slot())
        }

        slots[slotIndex].isReserved = true
        return EntityID(index: slotIndex, generation: slots[slotIndex].generation)
    }

    func releaseReserved(_ id: EntityID) {
        guard let slotIndex = validSlotIndex(for: id),
              slots[slotIndex].isReserved,
              !slots[slotIndex].isActive
        else {
            return
        }

        slots[slotIndex].isReserved = false
        slots[slotIndex].generation += 1
        pushFreeSlot(slotIndex)
    }

    func allocateID() -> EntityID {
        reserveID()
    }

    func insert(entity: any Entity, state: EntityState) {
        ensureSlotExists(for: state.id)

        guard let slotIndex = validSlotIndex(for: state.id) else {
            assertionFailure("Invalid entity id: \(state.id)")
            return
        }

        guard !slots[slotIndex].isActive else {
            assertionFailure("Duplicate entity id: \(state.id)")
            return
        }

        removeFromFreeList(slotIndex)
        slots[slotIndex].entity = entity
        slots[slotIndex].state = state
        slots[slotIndex].isReserved = false
        slots[slotIndex].activeIndex = activeSlots.count
        activeSlots.append(slotIndex)
    }

    func remove(_ id: EntityID) {
        guard let slotIndex = validSlotIndex(for: id),
              slots[slotIndex].isActive
        else {
            return
        }

        removeActiveSlot(slotIndex)
        slots[slotIndex].entity = nil
        slots[slotIndex].state = nil
        slots[slotIndex].isReserved = false
        slots[slotIndex].generation += 1
        pushFreeSlot(slotIndex)
    }

    func update(
        _ id: EntityID,
        _ body: (inout EntityState) -> Void
    ) {
        guard let slotIndex = validSlotIndex(for: id),
              slots[slotIndex].isActive,
              var state = slots[slotIndex].state
        else {
            return
        }

        body(&state)
        slots[slotIndex].state = state
    }

    func ids(kind: EntityKind) -> [EntityID] {
        var ids: [EntityID] = []
        ids.reserveCapacity(activeSlots.count)

        for slotIndex in activeSlots {
            guard let entity = slots[slotIndex].entity,
                  let state = slots[slotIndex].state,
                  type(of: entity).kind == kind
            else {
                continue
            }

            ids.append(state.id)
        }

        return ids
    }

    func updateEach(
        _ body: (inout any Entity, inout EntityState) -> Void
    ) {
        let slotsToUpdate = activeSlots

        for slotIndex in slotsToUpdate {
            guard slots.indices.contains(slotIndex),
                  slots[slotIndex].isActive,
                  var entity = slots[slotIndex].entity,
                  var state = slots[slotIndex].state
            else {
                continue
            }

            body(&entity, &state)

            guard slots.indices.contains(slotIndex),
                  slots[slotIndex].isActive,
                  slots[slotIndex].state?.id == state.id
            else {
                continue
            }

            slots[slotIndex].entity = entity
            slots[slotIndex].state = state
        }
    }

    func applyMovement(collisionSystem: CollisionSystem) {
        for slotIndex in activeSlots {
            guard var state = slots[slotIndex].state else { continue }

            collisionSystem.move(state: &state, velocity: state.velocity)
            slots[slotIndex].state = state
        }
    }

    func updateEachWithContacts(
        contacts: ContactState,
        _ body: (inout any Entity, inout EntityState, Contact) -> Void
    ) {
        let slotsToUpdate = activeSlots

        for slotIndex in slotsToUpdate {
            guard slots.indices.contains(slotIndex),
                  slots[slotIndex].isActive,
                  var entity = slots[slotIndex].entity,
                  var state = slots[slotIndex].state
            else {
                continue
            }

            for contact in contacts[state.id] {
                body(&entity, &state, contact)
            }

            guard slots.indices.contains(slotIndex),
                  slots[slotIndex].isActive,
                  slots[slotIndex].state?.id == state.id
            else {
                continue
            }

            slots[slotIndex].entity = entity
            slots[slotIndex].state = state
        }
    }

    func forEachState(_ body: (EntityState) -> Void) {
        for slotIndex in activeSlots {
            guard let state = slots[slotIndex].state else { continue }
            body(state)
        }
    }

    func bounds(for id: EntityID) -> Rect? {
        self[id]?.bounds
    }

    func forEachCollider(_ body: (EntityID, Int, Collider) -> Void) {
        for slotIndex in activeSlots {
            guard let state = slots[slotIndex].state else { continue }

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

    private func validSlotIndex(for id: EntityID) -> Int? {
        guard id.index >= 0,
              slots.indices.contains(id.index),
              slots[id.index].generation == id.generation
        else {
            return nil
        }

        return id.index
    }

    private func ensureSlotExists(for id: EntityID) {
        guard id.index >= 0 else {
            return
        }

        while slots.count <= id.index {
            let slotIndex = slots.count
            slots.append(Slot())

            if slotIndex != id.index {
                pushFreeSlot(slotIndex)
            }
        }
    }

    private func removeActiveSlot(_ slotIndex: Int) {
        guard let activeIndex = slots[slotIndex].activeIndex else {
            return
        }

        let lastSlot = activeSlots.removeLast()

        if activeIndex < activeSlots.count {
            activeSlots[activeIndex] = lastSlot
            slots[lastSlot].activeIndex = activeIndex
        }

        slots[slotIndex].activeIndex = nil
    }

    private func pushFreeSlot(_ slotIndex: Int) {
        slots[slotIndex].nextFree = freeHead
        freeHead = slotIndex
    }

    private func removeFromFreeList(_ slotIndex: Int) {
        guard freeHead != nil else {
            return
        }

        if freeHead == slotIndex {
            freeHead = slots[slotIndex].nextFree
            slots[slotIndex].nextFree = nil
            return
        }

        var current = freeHead

        while let currentIndex = current,
              let nextIndex = slots[currentIndex].nextFree {
            if nextIndex == slotIndex {
                slots[currentIndex].nextFree = slots[nextIndex].nextFree
                slots[nextIndex].nextFree = nil
                return
            }

            current = nextIndex
        }
    }
}
