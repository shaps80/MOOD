import Swift

public struct EntityRegistry: Sendable {
    private var data: [EntityKind: any Entity.Type] = [:]

    public init() { }

    public mutating func register(_ entity: Entity.Type) {
        guard data[entity.kind] == nil else {
            assertionFailure("Duplicate entity: \(String(describing: entity)), kind: \(entity.kind)")
            return
        }

        data[entity.kind] = entity
    }

    public func contains(kind: EntityKind) -> Bool {
        data[kind] != nil
    }

    public func make<E: Entity>(_ entity: E.Type) -> E? {
        make(kind: entity.kind) as? E
    }

    public func make(kind: EntityKind) -> (any Entity)? {
        guard let entity = data[kind] else {
            assertionFailure("Unknown entity kind: \(kind)")
            return nil
        }

        return entity.init()
    }
}
