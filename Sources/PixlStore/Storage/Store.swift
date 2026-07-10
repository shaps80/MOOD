public protocol _PixlEntityType: FrameEntity {
    associatedtype _PixlSchema: EntitySchema
    associatedtype _PixlGroup: StorageGroup

    init(id: EntityID, row: Int, frameID: UInt64, storage: Store)

    static func _pixlCreateComponents(storage: Store, row: Int)
    static func _pixlDestroyComponents(storage: Store, row: Int)
}

public final class Store {
    private struct StoreKey: Hashable {
        let schema: ObjectIdentifier
        let group: ObjectIdentifier
    }

    private struct EntityLocation {
        let entityType: ObjectIdentifier
        let handle: Any
        let destroy: (Store, Any) -> Void
    }

    public private(set) var currentFrameID: UInt64 = 0
    private var nextEntityIndex = 0
    private var entityLocations: [EntityID: EntityLocation] = [:]
    private var stores: [StoreKey: AnyObject] = [:]
    private var resolvedTypesByID: [ObjectIdentifier: PixlResolvedType] = [:]

    public init() {}

    public convenience init(for types: [any PixlStoreSchemaType.Type]) {
        self.init()
        register(types)
    }

    public func register(_ types: [any PixlStoreSchemaType.Type]) {
        for type in types {
            let properties = type.pixlSchemaMetadata.map { property in
                PixlResolvedProperty(
                    name: property.name,
                    valueType: property.valueType,
                    storageKind: property.valueType is any _PixlComponentType.Type ? .component : .value,
                    hasDefaultValue: property.hasDefaultValue
                )
            }

            resolvedTypesByID[ObjectIdentifier(type)] = PixlResolvedType(
                type: type,
                properties: properties
            )
        }
    }

    public func resolvedType(for type: any PixlStoreSchemaType.Type) -> PixlResolvedType? {
        resolvedTypesByID[ObjectIdentifier(type)]
    }

    public func beginFrame() {
        currentFrameID &+= 1
    }

    public func spawn<Entity: _PixlEntityType>(_ type: Entity.Type) -> Entity {
        let id = allocateEntityID()
        let entityStore = _pixlStore(Entity._PixlSchema.self, Entity._PixlGroup.self)
        let (handle, row) = entityStore.appendSlot()
        entityStore.columns.entityID[row] = id
        Entity._pixlCreateComponents(storage: self, row: row)
        registerEntity(id: id, type: Entity.self, handle: handle) { store, anyHandle in
            guard let handle = anyHandle as? ComponentHandle<Entity._PixlSchema, Entity._PixlGroup> else { return }
            let entityStore = store._pixlStore(Entity._PixlSchema.self, Entity._PixlGroup.self)
            if let row = entityStore.row(for: handle) {
                Entity._pixlDestroyComponents(storage: store, row: row)
            }
            entityStore.remove(handle)
        }
        return Entity(id: id, row: row, frameID: currentFrameID, storage: self)
    }

    public func entity<Entity: _PixlEntityType>(id: EntityID, as type: Entity.Type) -> Entity? {
        guard let handle: ComponentHandle<Entity._PixlSchema, Entity._PixlGroup> = handle(for: id, as: Entity.self) else {
            return nil
        }

        let entityStore = _pixlStore(Entity._PixlSchema.self, Entity._PixlGroup.self)
        guard let row = entityStore.row(for: handle) else {
            return nil
        }

        return Entity(id: id, row: row, frameID: currentFrameID, storage: self)
    }

    public func despawn(_ id: EntityID) {
        guard let location = entityLocations.removeValue(forKey: id) else {
            return
        }

        location.destroy(self, location.handle)
    }

    public func _pixlStore<Schema: ComponentSchema, Group: StorageGroup>(
        _ schema: Schema.Type = Schema.self,
        _ group: Group.Type = Group.self
    ) -> ComponentStore<Schema, Group> {
        let key = StoreKey(schema: ObjectIdentifier(Schema.self), group: ObjectIdentifier(Group.self))

        if let store = stores[key] as? ComponentStore<Schema, Group> {
            return store
        }

        let store = ComponentStore<Schema, Group>()
        stores[key] = store
        return store
    }

    public func assertWritableFrame(_ frameID: UInt64) {
        assert(
            frameID == currentFrameID,
            "Frame entity/component used outside the frame it was created in. Store EntityID instead."
        )
    }

    private func allocateEntityID() -> EntityID {
        defer { nextEntityIndex += 1 }
        return EntityID(index: nextEntityIndex, generation: 0)
    }

    private func registerEntity<Handle>(
        id: EntityID,
        type: Any.Type,
        handle: Handle,
        destroy: @escaping (Store, Any) -> Void
    ) {
        entityLocations[id] = EntityLocation(
            entityType: ObjectIdentifier(type),
            handle: handle,
            destroy: destroy
        )
    }

    private func handle<Handle>(for id: EntityID, as type: Any.Type) -> Handle? {
        guard let location = entityLocations[id],
              location.entityType == ObjectIdentifier(type)
        else {
            return nil
        }

        return location.handle as? Handle
    }
}

public struct EntityCollection {
    public unowned let store: Store

    public init(store: Store) {
        self.store = store
    }

    public func ofType<Entity: _PixlEntityType>(_ type: Entity.Type) -> EntityQuery<Entity> {
        EntityQuery(store: store)
    }
}

public struct EntityQuery<Entity: _PixlEntityType>: Sequence {
    private unowned let store: Store

    init(store: Store) {
        self.store = store
    }

    public func makeIterator() -> EntityIterator<Entity> {
        EntityIterator(store: store)
    }
}

public struct EntityIterator<Entity: _PixlEntityType>: IteratorProtocol {
    private unowned let store: Store
    private let entityStore: ComponentStore<Entity._PixlSchema, Entity._PixlGroup>
    private var row = 0

    init(store: Store) {
        self.store = store
        self.entityStore = store._pixlStore(Entity._PixlSchema.self, Entity._PixlGroup.self)
    }

    public mutating func next() -> Entity? {
        while row < entityStore.rowCount {
            let currentRow = row
            row += 1

            guard entityStore.isActiveRow(currentRow) else {
                continue
            }

            return Entity(
                id: entityStore.columns.entityID[currentRow],
                row: currentRow,
                frameID: store.currentFrameID,
                storage: store
            )
        }

        return nil
    }
}

public extension Store {
    var entities: EntityCollection {
        EntityCollection(store: self)
    }
}
