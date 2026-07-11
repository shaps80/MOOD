import Swift

final class ContactState {
    private var previousKeys: Set<Contact.Key> = []
    private var currentKeys: Set<Contact.Key> = []
    private var contactsByEntity: [EntityID: [Contact]] = [:]

    subscript(entityID: EntityID) -> [Contact] {
        contactsByEntity[entityID] ?? []
    }

    func begin() {
        currentKeys.removeAll(keepingCapacity: true)
        contactsByEntity.removeAll(keepingCapacity: true)
    }

    func reset() {
        previousKeys.removeAll(keepingCapacity: true)
        currentKeys.removeAll(keepingCapacity: true)
        contactsByEntity.removeAll(keepingCapacity: true)
    }

    func record(source: Contact.Endpoint, target: Contact.Target) {
        let key = Contact.Key(source: source, target: target)
        guard currentKeys.insert(key).inserted else {
            return
        }

        let phase: Contact.Phase = previousKeys.contains(key) ? .changed : .began
        let contact = Contact(source: source, target: target, phase: phase)

        contactsByEntity[source.id, default: []].append(contact)
    }

    func end() {
        for key in previousKeys where !currentKeys.contains(key) {
            let contact = Contact(
                source: key.source,
                target: key.target,
                phase: .ended
            )

            contactsByEntity[key.source.id, default: []].append(contact)
        }

        previousKeys = currentKeys
    }
}
