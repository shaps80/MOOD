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

    func record(source: Contact.Endpoint, target: Contact.Endpoint) {
        let key = Contact.Key(source: source, target: target)
        guard currentKeys.insert(key).inserted else {
            return
        }

        let phase: Contact.Phase = previousKeys.contains(key) ? .changed : .began
        let contact = Contact(source: source, target: target, phase: phase)

        contactsByEntity[source.id, default: []].append(contact)
    }

    func endFrame() {
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
