import Swift

final class ContactState {
    private var previousKeys: Set<Contact.Key> = []
    private var currentKeys: Set<Contact.Key> = []
    private var contactsByEntity: [Entity.ID: [Contact]] = [:]

    subscript(entityID: Entity.ID) -> [Contact] {
        contactsByEntity[entityID] ?? []
    }

    func beginFrame() {
        currentKeys.removeAll(keepingCapacity: true)
        contactsByEntity.removeAll(keepingCapacity: true)
    }

    func record(entity: (a: Entity.ID, b: Entity.ID), collider: (a: Int, b: Int)) {
        let key = Contact.Key(entity: entity, collider: collider)
        guard currentKeys.insert(key).inserted else {
            return
        }

        let phase: Contact.Phase = previousKeys.contains(key) ? .changed : .began
        let contact = Contact(entity: entity, collider: collider, phase: phase)

        contactsByEntity[entity.a, default: []].append(contact)
        contactsByEntity[entity.b, default: []].append(contact)
    }

    func endFrame() {
        for key in previousKeys where !currentKeys.contains(key) {
            let contact = Contact(
                entity: key.entity,
                collider: key.collider,
                phase: .ended
            )

            contactsByEntity[key.entity.a, default: []].append(contact)
            contactsByEntity[key.entity.b, default: []].append(contact)
        }

        previousKeys = currentKeys
    }
}
