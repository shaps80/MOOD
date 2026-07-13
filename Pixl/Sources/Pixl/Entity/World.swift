import PixlConcurrency
import PixlGraphics
import PixlPlatform

/// Fixed-capacity world storage and automatic entity lifecycle dispatcher.
public final class World {
    /// Startup-only capacities for a world.
    public struct Settings: Hashable, Sendable {
        public var entityTypeCapacity: UInt32

        public init(typeCapacity: UInt32 = 16) {
            precondition(typeCapacity > 0)
            self.entityTypeCapacity = typeCapacity
        }
    }

    private var stores: ContiguousArray<any WorldStore> = []
    private var storeRecords: ContiguousArray<WorldStoreRecord> = []
    private unowned var context: GameContext?
    public internal(set) var activeEntityCount: UInt32 = 0
    public internal(set) var inactiveEntityCount: UInt32 = 0

    public init(settings: Settings = .init()) {
        stores.reserveCapacity(Int(settings.entityTypeCapacity))
        storeRecords.reserveCapacity(Int(settings.entityTypeCapacity))
    }

    func attach(to context: GameContext) {
        precondition(self.context == nil, "World is already registered")
        self.context = context
    }

    /// Registers one concrete entity type and allocates its storage once.
    public func register<Value: Entity>(
        _ type: Value.Type,
        capacity: UInt32
    ) -> EntityStore<Value> {
        guard let context else {
            preconditionFailure("Register the World with GameContext before entity types")
        }
        precondition(capacity > 0, "Entity store capacity must be greater than zero")
        precondition(stores.count < stores.capacity, "World entity-type capacity exceeded")
        precondition(
            !stores.contains { ObjectIdentifier($0.valueType) == ObjectIdentifier(type) },
            "Entity type is already registered"
        )

        let store = EntityStore<Value>(
            storeIndex: UInt32(stores.count),
            capacity: capacity,
            context: context,
            world: self
        )
        stores.append(store)
        storeRecords.append(
            .init(slots: store.slots, capacity: capacity)
        )
        return store
    }

    /// Invalidates an identity immediately. Physical storage is reclaimed after
    /// the current typed lifecycle loop, if any.
    @discardableResult
    @inline(__always)
    public func despawn(_ entity: EntityID) -> Bool {
        guard entity.storeIndex < storeRecords.count else { return false }
        let record = storeRecords[Int(entity.storeIndex)]
        guard entity.slotIndex < record.capacity else { return false }
        let slot = record.slots.advanced(by: Int(entity.slotIndex))
        guard slot.pointee.generation == entity.generation,
              slot.pointee.state < record.capacity
        else { return false }

        slot.pointee.state = EntitySlotState.pending
        activeEntityCount &-= 1
        inactiveEntityCount &+= 1
        return true
    }

    func fixedUpdate(_ time: FixedTime, lanes: Lanes) {
        for store in stores {
            store.fixedUpdate(in: self, time: time, lanes: lanes)
        }
    }

    func update(_ time: UpdateTime, lanes: Lanes) {
        for store in stores {
            store.update(in: self, time: time, lanes: lanes)
        }
    }

    func render(
        on platform: any Platform,
        output: RenderTarget,
        frame: borrowing Frame,
        time: RenderTime
    ) throws {
        guard !stores.isEmpty else { return }
        let pass = frame.clear(target: output)
        for store in stores {
            try store.render(in: self, output: output, on: pass, time: time)
        }
    }
}
