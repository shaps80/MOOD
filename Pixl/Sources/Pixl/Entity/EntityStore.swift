import PixlConcurrency
import PixlPlatform

/// Fixed-capacity, typed storage for one ``Entity`` concrete type.
public final class EntityStore<Value: Entity>: WorldStore {
    let slots: UnsafeMutablePointer<EntitySlot>
    private let values: UnsafeMutablePointer<Value>
    private let denseSlots: UnsafeMutablePointer<UInt32>
    private let denseNext: UnsafeMutablePointer<UInt32>
    let storeIndex: UInt32
    private unowned(unsafe) let context: GameContext
    private unowned(unsafe) let world: World
    public let capacity: UInt32

    private var nextSlot: UInt32 = 0
    private var freeSlot: UInt32 = EntitySlotState.none
    private var nextDense: UInt32 = 0
    private var freeDense: UInt32 = EntitySlotState.none

    init(
        storeIndex: UInt32,
        capacity: UInt32,
        context: GameContext,
        world: World
    ) {
        self.storeIndex = storeIndex
        self.capacity = capacity
        self.context = context
        self.world = world
        slots = .allocate(capacity: Int(capacity))
        values = .allocate(capacity: Int(capacity))
        denseSlots = .allocate(capacity: Int(capacity))
        denseNext = .allocate(capacity: Int(capacity))
        slots.initialize(
            repeating: .init(generation: 1, state: EntitySlotState.none),
            count: Int(capacity)
        )
        denseSlots.initialize(repeating: EntitySlotState.none, count: Int(capacity))
        denseNext.initialize(repeating: EntitySlotState.none, count: Int(capacity))
    }

    deinit {
        for denseIndex in 0..<nextDense
        where denseSlots[Int(denseIndex)] != EntitySlotState.none {
            values.advanced(by: Int(denseIndex)).deinitialize(count: 1)
        }
        slots.deinitialize(count: Int(capacity))
        slots.deallocate()
        values.deallocate()
        denseSlots.deinitialize(count: Int(capacity))
        denseSlots.deallocate()
        denseNext.deinitialize(count: Int(capacity))
        denseNext.deallocate()
    }

    /// O(1), allocation-free spawn into pre-registered storage.
    @inline(__always)
    public func spawn() throws -> EntityID? {
        guard (freeSlot != EntitySlotState.none || nextSlot < capacity),
              (freeDense != EntitySlotState.none || nextDense < capacity)
        else { return nil }

        let value = try Value(context: context)
        let reusedInactive = freeDense != EntitySlotState.none
        let slotIndex = acquireSlot()!
        let denseIndex = acquireDense()!
        slots[Int(slotIndex)].state = denseIndex
        denseSlots[Int(denseIndex)] = slotIndex
        values.advanced(by: Int(denseIndex)).initialize(to: value)
        world.activeEntityCount &+= 1
        if reusedInactive {
            world.inactiveEntityCount &-= 1
        }
        return .init(
            storeIndex: storeIndex,
            slotIndex: slotIndex,
            generation: slots[Int(slotIndex)].generation
        )
    }

    /// O(1) scoped read without copying the entity value.
    public func withValue<Result>(
        for entity: EntityID,
        _ body: (UnsafePointer<Value>) throws -> Result
    ) rethrows -> Result? {
        guard let denseIndex = denseIndex(for: entity) else { return nil }
        return try body(.init(values.advanced(by: Int(denseIndex))))
    }

    /// O(1) scoped mutation without copying the entity value.
    public func update<Result>(
        _ entity: EntityID,
        _ body: (UnsafeMutablePointer<Value>) throws -> Result
    ) rethrows -> Result? {
        guard let denseIndex = denseIndex(for: entity) else { return nil }
        return try body(values.advanced(by: Int(denseIndex)))
    }

    var valueType: Any.Type { Value.self }

    private func acquireSlot() -> UInt32? {
        if freeSlot != EntitySlotState.none {
            let index = freeSlot
            freeSlot = slots[Int(index)].state
            return index
        }
        guard nextSlot < capacity else { return nil }
        defer { nextSlot &+= 1 }
        return nextSlot
    }

    private func acquireDense() -> UInt32? {
        if freeDense != EntitySlotState.none {
            let index = freeDense
            freeDense = denseNext[Int(index)]
            return index
        }
        guard nextDense < capacity else { return nil }
        defer { nextDense &+= 1 }
        return nextDense
    }

    private func denseIndex(for entity: EntityID) -> UInt32? {
        guard entity.storeIndex == storeIndex, entity.slotIndex < nextSlot else { return nil }
        let slot = slots[Int(entity.slotIndex)]
        guard slot.state < capacity, slot.generation == entity.generation else { return nil }
        return slot.state
    }

    private func retirePending() {
        for denseIndex in 0..<nextDense {
            let slotIndex = denseSlots[Int(denseIndex)]
            guard slotIndex != EntitySlotState.none,
                  slots[Int(slotIndex)].state == EntitySlotState.pending
            else { continue }
            retire(slotIndex: slotIndex, denseIndex: denseIndex)
        }
    }

    private func retire(slotIndex: UInt32, denseIndex: UInt32) {
        values.advanced(by: Int(denseIndex)).deinitialize(count: 1)
        denseSlots[Int(denseIndex)] = EntitySlotState.none
        denseNext[Int(denseIndex)] = freeDense
        freeDense = denseIndex
        releaseSlot(slotIndex)
    }

    private func releaseSlot(_ slotIndex: UInt32) {
        let slot = slots.advanced(by: Int(slotIndex))
        if slot.pointee.generation == .max {
            slot.pointee.state = EntitySlotState.none
            return
        }
        slot.pointee.generation &+= 1
        slot.pointee.state = freeSlot
        freeSlot = slotIndex
    }

    func fixedUpdate(in world: World, time: FixedTime, lanes: Lanes) {
        let limit = nextDense
        for denseIndex in 0..<limit {
            let slotIndex = denseSlots[Int(denseIndex)]
            guard slotIndex != EntitySlotState.none else { continue }
            let slot = slots[Int(slotIndex)]
            guard slot.state == denseIndex else { continue }
            values.advanced(by: Int(denseIndex)).pointee.fixedUpdate(
                entity: .init(
                    storeIndex: storeIndex,
                    slotIndex: slotIndex,
                    generation: slot.generation
                ),
                in: world,
                time: time,
                lanes: lanes
            )
        }
        retirePending()
    }

    func update(in world: World, time: UpdateTime, lanes: Lanes) {
        let limit = nextDense
        for denseIndex in 0..<limit {
            let slotIndex = denseSlots[Int(denseIndex)]
            guard slotIndex != EntitySlotState.none else { continue }
            let slot = slots[Int(slotIndex)]
            guard slot.state == denseIndex else { continue }
            values.advanced(by: Int(denseIndex)).pointee.update(
                entity: .init(
                    storeIndex: storeIndex,
                    slotIndex: slotIndex,
                    generation: slot.generation
                ),
                in: world,
                time: time,
                lanes: lanes
            )
        }
        retirePending()
    }

    func render(
        in world: World,
        output: RenderTarget,
        on pass: RenderPassEncoder,
        time: RenderTime
    ) throws {
        let limit = nextDense
        for denseIndex in 0..<limit {
            let slotIndex = denseSlots[Int(denseIndex)]
            guard slotIndex != EntitySlotState.none else { continue }
            let slot = slots[Int(slotIndex)]
            guard slot.state == denseIndex else { continue }
            try values.advanced(by: Int(denseIndex)).pointee.render(
                entity: .init(
                    storeIndex: storeIndex,
                    slotIndex: slotIndex,
                    generation: slot.generation
                ),
                in: world,
                output: output,
                on: pass,
                time: time
            )
        }
        retirePending()
    }
}
